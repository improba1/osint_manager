import asyncio
import trio
import logging
import warnings
from core.name_checker import check_all_sites
from core.email_checker import check_all_emails
from core.email_checker import check_holehe
from core.email_checker import check_gravatar
from core.email_checker import validate_mx_records
from core.email_checker import is_disposable

from core.phone_checker import check_phone_number

warnings.filterwarnings("ignore", category=RuntimeWarning)
logging.getLogger("charsetnormalizer").setLevel(logging.ERROR)
logging.getLogger("bs4").setLevel(logging.ERROR)
logging.getLogger("httpx").setLevel(logging.ERROR)

async def run_email_pipeline(email):
    print(f"Checking if {email} is fake...")
    is_valid = await validate_mx_records(email)

    if not is_valid: 
        return
    
    print(f"Checking is {email} is disposable...")
    is_valid = is_disposable(email)

    if is_valid:
        return
    
    print(f"Checking {email}...")
    await check_all_emails(email)

    print (f"Scanning websites via Holehe...")
    trio.run(check_holehe, email)

    print (f"Scanning via Gravatar...")
    await check_gravatar(email)

async def run_phone_pipeline(phone):
    print (f"Checking {phone}...")
    await check_phone_number(phone)

def main():
    operation = input("Choose an operation:\n1. Find by username\n2. Find by email\n3. Find by phone number")
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


if __name__ == "__main__":
    main()


# можно исправить то что логи от холехе пишутся только после проверки, можно сделать так чтобы они писались сразу
# так же можно добавить возможность ставить флажки типа *только найденные *цветной вывод (хотя насчет цвета надо подумать
# потому что важно чтобы цвет можно было использовать в десктопном приложении)