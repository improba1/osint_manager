import aiohttp
import asyncio
from colorama import Fore, Style
from core.config import SERVICES

async def check_single_site(url, service_name, semaphore, error_marker): 
   headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive"
   }

   async with semaphore:
      try:
         async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=headers, timeout=5) as response:
               if response.status == 200:
                  html_content = await response.text()
                  html_lowercased = html_content.lower()

                  if error_marker in html_lowercased:
                     print (f"[-] {service_name}: not found")
                     return service_name, False, url

                  else:
                     print (f"{Fore.GREEN}[+]{Style.RESET_ALL} {service_name} -> {url}")
                     return service_name, True, url
                  
               elif response.status == 404:
                  print(f"[-] {service_name}: 404 not found")
                  return service_name, False, url
               else:
                    print(f"[-] {service_name}: {response.status}")
                    return service_name, False, url
      except Exception:
         print(f"[X] {service_name}: unreachable")
         return service_name, False, url
      

async def check_all_sites(username):
   semaphore = asyncio.Semaphore(5)
   tasks = []

   for service_name, service_data in SERVICES.items():
      ready_url = service_data["url"].format(username)
      marker = service_data["error_marker"]
      task = asyncio.create_task(check_single_site(ready_url, service_name, semaphore, marker))
      tasks.append(task)
      await asyncio.sleep(0.2)
   results = await asyncio.gather(*tasks)
   return results