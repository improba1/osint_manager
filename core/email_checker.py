import asyncio
from colorama import Fore, Style
import copy
from curl_cffi.requests import AsyncSession
from holehe import core as holehe_core
import dns.asyncresolver
import httpx
import trio 
import hashlib
import time
from core.config import EMAIL_SERVICES

_disposable_domains_cache = None

class HoleheArgs:
    def __init__(self):
        self.onlyused = False   
        self.nocolor = False
        self.noclear = True
        self.nopasswordrecovery = False
        self.csvoutput = False
        self.timeout = 10

def _fill_payload(payload, email):
    for key, value in payload.items():
        if isinstance(value, dict):
            _fill_payload(value, email)
        elif isinstance(value, str):
            payload[key] = value.format(email)
    return payload

async def _check_single_email(url, method, service_name, semaphore, template, error_marker):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive"
   }
    result = {
        "service_name": service_name, 
        "status": "", 
        "error_message": "", 
        "url" : url, 
        "leaks" : 0, 
        "leaks_source" : {}
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
                    result["status"] = "error"
                    result["error_message"] = "Not found"
                    # print (f"[-] {service_name}: not found")
                    return result

                else:
                    data = response.json()
                    leaks_amount = data.get('found', 0)
                    sources = data.get("sources") or data.get("breaches") or []
                    if sources and isinstance(sources[0], list):
                        sources = sources[0]
                    if leaks_amount == 0:
                        leaks_amount = len(sources)
                        result["leaks"] = leaks_amount
                    # print (f"{Fore.GREEN}[+]{Style.RESET_ALL} {service_name} -> {url} (found {Fore.RED}{leaks_amount}{Style.RESET_ALL} leaks)")
                    for source in sources:
                        if isinstance(source, dict):
                            name = source.get("name", "Unknown")
                            date = source.get("date", "No date")
                            date_str = f"({date})" if date else ""
                            result["leaks_source"][name] = date_str
                            # print (f"   --> {name} {date_str}")
                        else:
                            name = source
                            date_str = ""
                            result["leaks_source"][name] = date_str
                            # print (f"   --> {name} {date_str}")
                    result["status"] = "success"
                    return result
                
            elif response.status_code == 404:
                result["status"] = "error"
                result["error_message"] = "Not found"
                # print(f"[-] {service_name}: 404 not found")
                return result
            else:
                result["status"] = "error"
                result["error_message"] = response.status_code
                # print(f"[-] {service_name}: {response.status_code}")
                return result
      except Exception:
         result["status"] = "error"
         result["error_message"] = "Unreachable"
        #  print(f"[X] {service_name}: unreachable")
         return result

async def check_all_emails(email):
    semaphore = asyncio.Semaphore(5)
    tasks = []

    for service_name, service_data in EMAIL_SERVICES.items():
        ready_url = service_data["url"].format(email)
        method = service_data["method"]
        marker = service_data["error_marker"]
        payload_tmp = copy.deepcopy(service_data["payload_template"])
        template = _fill_payload(payload_tmp, email)
        task = asyncio.create_task(_check_single_email(ready_url, method, service_name, semaphore, template, marker))
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
    async with trio.open_nursery() as nursery:
        for website in websites:
            nursery.start_soon(holehe_core.launch_module, website, email, client, out)
    await client.aclose()
    out = sorted(out, key=lambda i: i['name'])
    # print(out)
    return out
    # holehe_core.print_result(out, args, email, start_time=start_time, websites=websites)

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
    # print(f"   --> Raw json url: {ready_url}")
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

                result["name"] = display_name
                result["profile_url"] = profile_url
                result["profile_photo"] = avatar_url
                result["location"] = location
                result["about_me"] = description
                result["job"] = job
                result["company"] = company

                # print(f"   --> Name: {display_name}")
                # print(f"   --> Location: {location}")
                # print(f"   --> About me: {description}")
                # print(f"   --> Job: {job}")
                # print(f"   --> Company: {company}")
                # print(f"   --> Profile: {profile_url}")
                # print(f"   --> Profile photo: {avatar_url}")

                verified_accounts = content.get("verified_accounts", [])
                if verified_accounts:
                    # print(f"   --> Found social media:")
                    for account in verified_accounts:
                        label = account.get("service_label", "Unknown")
                        link = account.get("url", "No url")
                        result["verified_accounts"][label] = link
                        # print(f"       * {label}: {link}")
                # else:
                    # print(f"   --> No linked social media")

            elif response.status_code == 404:
                result["status"] = "error"
                result["error_message"] = "Not found"
                # print("Profile not found")
            else:
                result["status"] = "error"
                result["error_message"] = "Unreachable"
                # print (f"{response.status_code}: unreachable")
    return result


async def validate_mx_records(email):
    result = {
        "status": "", 
        "error_message" : "", 
        "target": email, 
        "is_valid": False
    }
    domain = email.split('@')[1]
    try:
        await dns.asyncresolver.resolve(domain, "MX")
        # print("Email is not fake")
        result["status"] = "success"
        result["is_valid"] = True
        return result
    except Exception:
        # print("Email is fake")
        result["status"] = "success"
        result["is_valid"] = False
        return result
    
def is_disposable(email):
    global _disposable_domains_cache

    result = {
        "status": "", 
        "error_message" : "", 
        "target": email, 
        "is_disposable": False
    }
    domain = email.split('@')[1]

    if _disposable_domains_cache is None:
        _disposable_domains_cache = set()
        try:
            with open("disposable_email_blocklist.conf", "r", encoding="utf-8") as file:
                for line in file:
                    line = line.strip()
                    if line:
                        _disposable_domains_cache.add(line)
        except Exception as e:
            result["status"] = "error"
            result["error_message"] = e
            # print(e)
            return result
        
    if domain in _disposable_domains_cache:
        result["status"] = "success"
        result["is_disposable"] = True
        # print("Email is disposable")
        return result
    result["status"] = "success"
    result["is_disposable"] = False
    # print("Email is not disposable")
    return result
