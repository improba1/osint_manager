import re
import phonenumbers
from phonenumbers import carrier, geocoder, PhoneNumberFormat
import webbrowser
import httpx
import json
from urllib.parse import quote_plus
from telethon.tl.types import InputPhoneContact
from telethon.tl.functions.contacts import ImportContactsRequest, DeleteContactsRequest


def clean_phone_number(phone):
    phone = re.sub(r"\D", "", phone)
    return phone

async def check_telegram(phone, tg_client):
    print(f"Checking for {phone} in Telegram...")
    print("Warning! Do not use your main account to prevent ban")
    try:
        contact = InputPhoneContact(client_id=0, phone=phone, first_name="Name", last_name="LastName")
        contacts = await tg_client(ImportContactsRequest([contact]))
        if len(contacts.users) != 0:
            for user in contacts.users:
                print(f"Id: {user.id}")
                print(f"Username: {user.username}")
                print(f"First name: {user.first_name}")
                print(f"Last name: {user.last_name}")
                await tg_client(DeleteContactsRequest([user.id]))
        else:
            print ("User not found")
    except Exception as e:
        print(e)

def get_phone_object(phone):
    try:
        phone_object = phonenumbers.parse(phone)
        return phone_object
    except Exception as e:
        print(e)
        return None

def open_watsapp_chat(phone):
    whatsapp_url = f"https://wa.me/{phone}"
    print(f"Opening {whatsapp_url} via WhatsApp...")
    webbrowser.open(whatsapp_url)

def open_telegram_chat(phone):
    telegram_url = f"https://t.me/{phone}"
    print(f"Opening {telegram_url} via Telegram...")
    webbrowser.open(telegram_url)

def open_viber_chat(phone):
    viber_url = f"viber://chat?number={phone}"
    print(f"Opening {viber_url} via Viber...")
    webbrowser.open(viber_url)

def check_if_valid(phone_object):
    is_valid = phonenumbers.is_valid_number(phone_object)
    if not is_valid:
        print(f"Phone is not valid.")
        return
    
async def find_country_and_carrier(phone_object):
    print (f"Country: {geocoder.description_for_number(phone_object, "en")}")
    print(f"Carrier name: {carrier.name_for_number(phone_object, "en")}")

def search_google_dorks(phone_object):
    phone1= phonenumbers.format_number(phone_object, PhoneNumberFormat.INTERNATIONAL)
    phone2= phonenumbers.format_number(phone_object, PhoneNumberFormat.NATIONAL)
    phone3= phone1.replace(' ', '-')
    phone4= phonenumbers.format_number(phone_object, PhoneNumberFormat.E164).replace('+', '')

    print(f"{phone1} {phone2} {phone3} {phone4}")
    dork_query = f'"{phone1}" OR "{phone2}" OR "{phone3}" OR "{phone4}"'
    safe_url = f"https://www.google.com/search?q={quote_plus(dork_query)}"
    webbrowser.open(safe_url)

    
async def check_phone_number(phone, tg_client):
    phone = f"+{clean_phone_number(phone)}"
    phone_object = get_phone_object(phone)
    
    check_if_valid(phone_object)
    find_country_and_carrier(phone_object)
    search_google_dorks(phone_object)
    # check_telegram(phone, tg_client)
    # open_telegram_chat(phone)
    # open_viber_chat(phone)
    # open_watsapp_chat(phone)

    
    



