import re
import phonenumbers
from phonenumbers import carrier, geocoder

def clean_phone_number(phone):
    phone = re.sub(r"\D", "", phone)
    return phone

async def check_phone_number(phone):
    phone = f"+{clean_phone_number(phone)}"
    try:
        phone_object = phonenumbers.parse(phone)
    except Exception as e:
        print(e)
        return
    
    is_valid = phonenumbers.is_valid_number(phone_object)
    if not is_valid:
        print(f"{phone} is not valid.")
        return
    
    print (f"Country: {geocoder.description_for_number(phone_object, "en")}")
    print(f"Carrier name: {carrier.name_for_number(phone_object, "en")}")

    



