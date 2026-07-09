import asyncio
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

from core.phone_checker import check_phone_number

warnings.filterwarnings("ignore", category=RuntimeWarning)
logging.getLogger("charsetnormalizer").setLevel(logging.ERROR)
logging.getLogger("bs4").setLevel(logging.ERROR)
logging.getLogger("httpx").setLevel(logging.ERROR)

load_dotenv()
API_ID = os.getenv("TELEGRAM_API_ID")
API_HASH = os.getenv("TELEGRAM_API_HASH")
_TG_CLIENT_ = None

async def init_telegram_client():
    global _TG_CLIENT_
    if _TG_CLIENT_ is None:
        _TG_CLIENT_ = telethon.TelegramClient('osint_session', API_ID, API_HASH)
    await _TG_CLIENT_.start()

async def run_email_pipeline(email):
    print(f"Checking if {email} is fake...")
    is_valid = await validate_mx_records(email)

    if not is_valid: 
        return
    
    print(f"Checking is {email} is disposable...")
    is_valid = is_disposable(email)

    if not is_valid:
        return
    
    print(f"Checking {email}...")
    await check_all_emails(email)

    print (f"Scanning websites via Holehe...")
    trio.run(check_holehe, email)

    print (f"Scanning via Gravatar...")
    await check_gravatar(email)

async def run_phone_pipeline(phone):
    
    print (f"Checking {phone}...")
    # await init_telegram_client()
    await check_phone_number(phone, _TG_CLIENT_)

def main():
    operation = input("Choose an operation:\n1. Find by username\n2. Find by email\n3. Find by phone number\n4. Extract metadata")
    if operation == '1':
        username = input("Enter an username: ")
        print(f"Checking {username}...")
        asyncio.run(check_all_sites(username))
    if operation == '2':
        email = input("Enter an email: ")
        asyncio.run(run_email_pipeline(email))
    if operation == '3':
        phone = input("Enter a phone number: ")
        asyncio.run(run_phone_pipeline(phone))
    if operation == '4':
        file_path = input("Enter file path: ")
        extract_image_metadata(file_path)


if __name__ == "__main__":
    main()


# можно исправить то что логи от холехе пишутся только после проверки, можно сделать так чтобы они писались сразу
# так же можно добавить возможность ставить флажки типа *только найденные *цветной вывод (хотя насчет цвета надо подумать
# потому что важно чтобы цвет можно было использовать в десктопном приложении)