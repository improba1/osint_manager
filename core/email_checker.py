import asyncio
from colorama import Fore, Style
import copy
from curl_cffi.requests import AsyncSession
from holehe import core as holehe_core
import importlib
import os
import holehe
import httpx
import trio 
import hashlib
import time
from core.config import EMAIL_SERVICES

class HoleheArgs:
    def __init__(self):
        self.onlyused = False   
        self.nocolor = False
        self.noclear = True
        self.nopasswordrecovery = False
        self.csvoutput = False
        self.timeout = 10

def fill_payload(payload, email):
    for key, value in payload.items():
        if isinstance(value, dict):
            fill_payload(value, email)
        elif isinstance(value, str):
            payload[key] = value.format(email)
    return payload

async def check_single_email(url, method, service_name, semaphore, template, error_marker):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive"
   }
    async with semaphore:
      try:
         async with AsyncSession() as session:
            response = await session.request(
                method = method, 
                url = url, 
                json=template,
                headers=headers, 
                timeout=5, 
                impersonate="chrome"
            )
            if response.status_code == 200:
                html_content = response.text
                html_lowercased = html_content.lower()
                if error_marker in html_lowercased:
                    print (f"[-] {service_name}: not found")
                    return service_name, False, url

                else:
                    data = response.json()
                    leaks_amount = data.get('found', 0)
                    sources = data.get("sources") or data.get("breaches") or []
                    if sources and isinstance(sources[0], list):
                        sources = sources[0]
                    if leaks_amount == 0:
                        leaks_amount = len(sources)
                    print (f"{Fore.GREEN}[+]{Style.RESET_ALL} {service_name} -> {url} (found {Fore.RED}{leaks_amount}{Style.RESET_ALL} leaks)")
                    for source in sources:
                        if isinstance(source, dict):
                            name = source.get("name", "Unknown")
                            date = source.get("date", "No date")
                            date_str = f"({date})" if date else ""
                            print (f"   --> {name} {date_str}")
                        else:
                            name = source
                            date_str = ""
                            print (f"   --> {name} {date_str}")
                    return service_name, True, url
                
            elif response.status_code == 404:
                print(f"[-] {service_name}: 404 not found")
                return service_name, False, url
            else:
                print(f"[-] {service_name}: {response.status_code}")
                return service_name, False, url
      except Exception:
         print(f"[X] {service_name}: unreachable")
         return service_name, False, url

async def check_all_emails(email):
    semaphore = asyncio.Semaphore(5)
    tasks = []

    for service_name, service_data in EMAIL_SERVICES.items():
        ready_url = service_data["url"].format(email)
        method = service_data["method"]
        marker = service_data["error_marker"]
        payload_tmp = copy.deepcopy(service_data["payload_template"])
        template = fill_payload(payload_tmp, email)
        task = asyncio.create_task(check_single_email(ready_url, method, service_name, semaphore, template, marker))
        tasks.append(task)
        await asyncio.sleep(0.2)
    results = await asyncio.gather(*tasks)
    return results

async def check_holehe(email):
    args = HoleheArgs()
    modules = holehe_core.import_submodules("holehe.modules")
    websites = holehe_core.get_functions(modules, args)

    client = httpx.AsyncClient(timeout=args.timeout)
    out = []

    start_time = time.time()
    async with trio.open_nursery() as nursery:
        for website in websites:
            nursery.start_soon(holehe_core.launch_module, website, email, client, out)
    await client.aclose()
    out = sorted(out, key=lambda i: i['name'])
    holehe_core.print_result(out, args, email, start_time=start_time, websites=websites)

async def check_gravatar(email):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive"
   }
    ready_email = email.strip().lower()
    email_md5 = hashlib.sha256(ready_email.encode('utf-8')).hexdigest()
    url = "https://api.gravatar.com/v3/profiles/{}"
    ready_url = url.format(email_md5)
    print(f"   --> Raw json url: {ready_url}")
    async with AsyncSession() as session:
            response = await session.request(
                method = 'GET', 
                url = ready_url, 
                headers=headers, 
                timeout=5, 
                impersonate="chrome"
            )
            if response.status_code == 200:
                content = response.json()

                display_name = content.get("display_name", "Unknown")
                profile_url = content.get("profile_url", "Unknown")
                avatar_url = content.get("avatar_url", "Unknown")
                location = content.get("location", "Unknown")
                description = content.get("description", "Unknown")
                job = content.get("job_title", "Unknown")
                company = content.get("company", "Unknown")

                print(f"   --> Name: {display_name}")
                print(f"   --> Location: {location}")
                print(f"   --> About me: {description}")
                print(f"   --> Job: {job}")
                print(f"   --> Company: {company}")
                print(f"   --> Profile: {profile_url}")
                print(f"   --> Profile photo: {avatar_url}")

                verified_accounts = content.get("verified_accounts", [])
                if verified_accounts:
                    print(f"   --> Found social media:")
                    for account in verified_accounts:
                        label = account.get("service_label", "Unknown")
                        link = account.get("url", "No url")
                        print(f"       * {label}: {link}")
                else:
                    print(f"   --> No linked social media")

            elif response.status_code == 404:
                print("Profile nor found")
            else:
                print (f"{response.status_code}: unreachable")




