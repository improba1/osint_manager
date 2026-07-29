import re
import phonenumbers
from phonenumbers import carrier, geocoder, PhoneNumberFormat
import webbrowser
import httpx
import json
from urllib.parse import quote_plus
from telethon.tl.types import InputPhoneContact
from telethon.tl.functions.contacts import ImportContactsRequest, DeleteContactsRequest


def _clean_phone_number(phone):
    
    phone = re.sub(r"\D", "", phone)
    return phone

async def check_telegram(phone, tg_client):
    result = {
        "status" : "",
        "error_message" : "",
        "id" : "" ,
        "username" : "",
        "first_name" : "",
        "last_name" : ""
    }
    # print(f"Checking for {phone} in Telegram...")
    # print("Warning! Do not use your main account to prevent ban")
    try:
        contact = InputPhoneContact(client_id=0, phone=phone, first_name="Name", last_name="LastName")
        contacts = await tg_client(ImportContactsRequest([contact]))
        if len(contacts.users) != 0:
            for user in contacts.users:
                # print(f"Id: {user.id}")
                # print(f"Username: {user.username}")
                # print(f"First name: {user.first_name}")
                # print(f"Last name: {user.last_name}")

                result["id"] = user.id
                result["username"] = user.username
                result["first_name"] = user.first_name
                result["last_name"] = user.last_name
                result["status"] = "success"
                await tg_client(DeleteContactsRequest([user.id]))
                return result
        else:
            result["status"] = "error"
            result["error_message"] = "User not found"
            # print ("User not found")
            return result
    except Exception as e:
        result["status"] = "error"
        result["error_message"] = e
        # print(e)
        return result

def _get_phone_object(phone):
    try:
        phone_object = phonenumbers.parse(phone)
        return phone_object
    except Exception as e:
        # print(e)
        return None

def open_watsapp_chat(phone):
    result = {
        "url" : ""
    }
    whatsapp_url = f"https://wa.me/{phone}"
    # print(f"Opening {whatsapp_url} via WhatsApp...")
    result["url"] = whatsapp_url
    # webbrowser.open(whatsapp_url)
    return result

def open_telegram_chat(phone):
    result = {
        "url" : ""
    }
    telegram_url = f"https://t.me/{phone}"
    # print(f"Opening {telegram_url} via Telegram...")
    result["url"] = telegram_url
    # webbrowser.open(telegram_url)
    return result

def open_viber_chat(phone):
    result = {
        "url" : ""
    }
    viber_url = f"viber://chat?number={phone}"
    # print(f"Opening {viber_url} via Viber...")
    result["url"] = viber_url
    # webbrowser.open(viber_url)
    return result

def check_if_valid(phone_object):
    phone_object = _get_phone_object(phone_object)
    print(phone_object)
    result = {
        "is_valid" : False
    }
    is_valid = phonenumbers.is_valid_number(phone_object)
    if not is_valid:
        # print(f"Phone is not valid.")
        return result
    result["is_valid"] = True
    return result
    
async def find_country_and_carrier(phone_object):
    phone_object = _get_phone_object(phone_object)
    result = {
        "country" : "", 
        "carrier_name" : ""
    }
    country = geocoder.description_for_number(phone_object, "en")
    carrier_name = carrier.name_for_number(phone_object, "en")
    result["country"] = country
    result["carrier_name"] = carrier_name
    # print (f"Country: {geocoder.description_for_number(phone_object, "en")}")
    # print(f"Carrier name: {carrier.name_for_number(phone_object, "en")}")
    return result

def search_google_dorks(phone_object):
    phone_object = _get_phone_object(phone_object)
    result = {
        "url": ""
    }
    phone1= phonenumbers.format_number(phone_object, PhoneNumberFormat.INTERNATIONAL)
    phone2= phonenumbers.format_number(phone_object, PhoneNumberFormat.NATIONAL)
    phone3= phone1.replace(' ', '-')
    phone4= phonenumbers.format_number(phone_object, PhoneNumberFormat.E164).replace('+', '')

    # print(f"{phone1} {phone2} {phone3} {phone4}")
    dork_query = f'"{phone1}" OR "{phone2}" OR "{phone3}" OR "{phone4}"'
    safe_url = f"https://www.google.com/search?q={quote_plus(dork_query)}"
    result["url"] = safe_url
    # webbrowser.open(safe_url)
    return result

    
async def check_phone_number(phone, tg_client):
    phone = f"+{_clean_phone_number(phone)}"
    phone_object = _get_phone_object(phone)
    
    check_if_valid(phone_object)
    find_country_and_carrier(phone_object)
    search_google_dorks(phone_object)
    # check_telegram(phone, tg_client)
    # open_telegram_chat(phone)
    # open_viber_chat(phone)
    # open_watsapp_chat(phone)

    
    



