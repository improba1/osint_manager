from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi import WebSocket
import json
import uvicorn
import anyio
import trio

import logging
import warnings
import os
from dotenv import load_dotenv
import telethon

from core.name_checker import check_all_sites

from core.email_checker import check_all_emails
from core.email_checker import check_holehe
from core.email_checker import check_gravatar
from core.email_checker import validate_mx_records
from core.email_checker import is_disposable

from core.file_checker import extract_image_metadata

from core.phone_checker import search_google_dorks
from core.phone_checker import find_country_and_carrier
from core.phone_checker import check_if_valid
from core.phone_checker import open_viber_chat
from core.phone_checker import open_telegram_chat
from core.phone_checker import open_watsapp_chat
from core.phone_checker import check_telegram

warnings.filterwarnings("ignore", category=RuntimeWarning)
logging.getLogger("charsetnormalizer").setLevel(logging.ERROR)
logging.getLogger("bs4").setLevel(logging.ERROR)
logging.getLogger("httpx").setLevel(logging.ERROR)

load_dotenv()
API_ID = os.getenv("TELEGRAM_API_ID")
API_HASH = os.getenv("TELEGRAM_API_HASH")
_TG_CLIENT_ = None

app=FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

class UsernameRequest(BaseModel): 
    username: str

class EmailRequest(BaseModel):
    email: str

class PhoneRequest(BaseModel):
    phone: str

async def init_telegram_client():
    global _TG_CLIENT_
    if _TG_CLIENT_ is None:
        _TG_CLIENT_ = telethon.TelegramClient('osint_session', API_ID, API_HASH)
    await _TG_CLIENT_.start()


# usernames

"""
    result = {
         "service_name": "", 
         "status": "", 
         "error_message": "", 
         "url" : ""
      }
"""
@app.websocket("/api/username")
async def search_by_username(websocket: WebSocket):
    await websocket.accept()
    try:
        data = await websocket.receive_text()
        payload = json.loads(data)
        target_username = payload.get("username")
        await check_all_sites(websocket, target_username)
        await websocket.send_json({"status": "COMPLETED"})
    except Exception as e:
        await websocket.send_json({"status": "error", "error_message": str(e)})
    finally:
        # Кладем трубку
        await websocket.close()


# emails

"""
    result = {
        "status": "", 
        "error_message" : "", 
        "target": email, 
        "is_disposable": False
    }
"""
@app.post("/api/email/disposable")
async def email_is_disposable(payload: EmailRequest):
    try:
        results = is_disposable(payload.email)
        return {"status": "success", "target": payload.email, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


"""
    result = {
        "status": "", 
        "error_message" : "", 
        "target": email, 
        "is_valid": False
    }
"""
@app.post("/api/email/validate")
async def email_validate(payload: EmailRequest):
    try:
        results = await validate_mx_records(payload.email)
        return {"status": "success", "target": payload.email, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


"""
    result = {
        "status": "", 
        "error_message" : "", 
        "target": ready_email, 
        "raw_json_url" : ready_url,
        "name": "",
        "location" : "",
        "about_me" : "",
        "job" : "",
        "company" : "",
        "profile_url" : "",
        "profile_photo" : "",
        "verified_accounts" : []
    }
"""
@app.post("/api/email/gravatar")
async def email_gravatar(payload: EmailRequest):
    try:
        results = await check_gravatar(payload.email)
        return {"status": "success", "target": payload.email, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


"""
    result = {
        "name" : "",
        "domain" : "",
        "method" : "",
        "frequent_rate_limit" : "",
        "rateLimit" : "",
        "exists" : "",
        "emailrecovery" : "",
        "phoneNumber" : "",
        "other" : ""
    }
"""
@app.post("/api/email/holehe")
async def email_holehe(payload: EmailRequest):
    try:
        def _execute_trio():
            return trio.run(check_holehe, payload.email) 

        results = await anyio.to_thread.run_sync(_execute_trio)
        
        # ВАЖНО: Оборачиваем список results в словарь!
        return {"status": "success", "target": payload.email, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
"""
    result = {
        "service_name": service_name, 
        "status": "", 
        "error_message": "", 
        "url" : url, 
        "leaks" : 0, 
        "leaks_source" : {}
    }
"""
@app.websocket("/api/email")
async def search_by_email(websocket : WebSocket):
    await websocket.accept() 
    try:
        data = await websocket.receive_text()
        payload = json.loads(data)
        target_email = payload.get("email")
        await check_all_emails(websocket, target_email)
        await websocket.send_json({"status" : "COMPLETED"})
    except Exception as e:
        # raise HTTPException(status_code=500, detail=str(e))
        await websocket.send_json({"status": "error", "error_message": str(e)})
    finally:
        # Кладем трубку
        await websocket.close()



# phone numbers


"""
    result = {
        "url": ""
    }
"""
@app.post("/api/phone/dorks")
async def search_by_phone(payload: PhoneRequest):
    try:
        results = search_google_dorks(payload.phone)
        return {"status": "success", "target": payload.phone, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    

"""
    result = {
        "country" : "", 
        "carrier_name" : ""
    }
"""
@app.post("/api/phone/country")
async def phone_country_and_carrier(payload: PhoneRequest):
    try:
        results = await find_country_and_carrier(payload.phone)
        return {"status": "success", "target": payload.phone, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


"""
    result = {
        "is_valid" : False
    }
"""
@app.post("/api/phone/valid")
async def phone_valid(payload: PhoneRequest):
    try:
        results = check_if_valid(payload.phone)
        return {"status": "success", "target": payload.phone, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


"""
    result = {
        "url" : ""
    }
"""
@app.post("/api/phone/viber/chat")
async def phone_viber_chat(payload: PhoneRequest):
    try:
        results =  open_viber_chat(payload.phone)
        return {"status": "success", "target": payload.phone, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    

"""
    result = {
        "url" : ""
    }
"""
@app.post("/api/phone/telegram/chat")
async def phone_telegram_chat(payload: PhoneRequest):
    try:
        results =  open_telegram_chat(payload.phone)
        return {"status": "success", "target": payload.phone, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    

"""
    result = {
        "url" : ""
    }
"""
@app.post("/api/phone/whatsapp/chat")
async def phone_whatsapp_chat(payload: PhoneRequest):
    try:
        results =  open_watsapp_chat(payload.phone)
        return {"status": "success", "target": payload.phone, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    

"""
    result = {
        "status" : "",
        "error_message" : "",
        "id" : "" ,
        "username" : "",
        "first_name" : "",
        "last_name" : ""
    }
"""
@app.post("/api/phone/telegram")
async def phone_telegram(payload: PhoneRequest):
    try:
        await init_telegram_client()
        results = await check_telegram(payload.phone, _TG_CLIENT_)
        return {"status": "success", "target": payload.phone, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# metadata

"""
    result = { 
        "status":"processing", 
        "has_exif": False, 
        "error_message": "", 
        "hardware": {}, 
        "software": {}, 
        "gps": {} 
    }
"""
@app.post("/api/metadata")
async def extract_metadata(file: UploadFile = File(...)):
    try:
        file_bytes = await file.read()
        metadata = extract_image_metadata(file_bytes)
        return {"status": "success", "filename": file.filename, "metadata": metadata}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("api:app", host="127.0.0.1", port=8000, reload=True)