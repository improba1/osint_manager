import asyncio
import trio
import logging
import warnings
from core.name_checker import check_all_sites
from core.email_checker import check_all_emails
from core.email_checker import check_holehe
from core.email_checker import check_gravatar

warnings.filterwarnings("ignore", category=RuntimeWarning)
logging.getLogger("charsetnormalizer").setLevel(logging.ERROR)
logging.getLogger("bs4").setLevel(logging.ERROR)
logging.getLogger("httpx").setLevel(logging.ERROR)

async def run_email_pipeline(email):
    # print(f"Checking {email}...")
    # await check_all_emails(email)

    # print (f"Scanning websites via Holehe...")
    # trio.run(check_holehe, email)

    print (f"Scanning via Gravatar...")
    await check_gravatar(email)

def main():
    operation = input("Choose an operation:\n1. Find by username\n2. Find by email\n")
    if operation == '1':
        username = input("Enter an username: ")
        print(f"Checking {username}...")
        asyncio.run(check_all_sites(username))
    if operation == '2':
        email = input("Enter an email: ")
        asyncio.run(run_email_pipeline(email))


if __name__ == "__main__":
    main()


# можно исправить то что логи от холехе пишутся только после проверки, можно сделать так чтобы они писались сразу
# так же можно добавить возможность ставить флажки типа *только найденные *цветной вывод (хотя насчет цвета надо подумать
# потому что важно чтобы цвет можно было использовать в десктопном приложении)