import aiohttp
import asyncio
from fastapi import WebSocket
from colorama import Fore, Style
from core.config import SERVICES

async def _check_single_site(websocket : WebSocket, url, service_name, semaphore, error_marker): 
   headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive"
   }

   async with semaphore:
      result = {
         "service_name": "", 
         "status": "", 
         "error_message": "", 
         "url" : ""
      }
      result["service_name"] = service_name
      result["url"] = url
      try:
         async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=headers, timeout=5) as response:
               if response.status == 200:
                  html_content = await response.text()
                  html_lowercased = html_content.lower()

                  if error_marker in html_lowercased:
                     result["status"] = "error"
                     result["error_message"] = "not found"
                     # print (f"[-] {service_name}: not found")

                  else:
                     result["status"] = "success"
                  
               elif response.status == 404:
                  result["status"] = "error"
                  result["error_message"] = "not found"
                  # print(f"[-] {service_name}: 404 not found")
               else:
                    result["status"] = "error"
                    result["error_message"] = f"{response.status}"
                  #   print(f"[-] {service_name}: {response.status}")
      except Exception:
         result["status"] = "error"
         result["error_message"] = "unreachable"
         # print(f"[X] {service_name}: unreachable")
      await websocket.send_json(result)
      return result


async def check_all_sites(websocket : WebSocket, username):
   semaphore = asyncio.Semaphore(5)
   tasks = []

   for service_name, service_data in SERVICES.items():
      ready_url = service_data["url"].format(username)
      marker = service_data["error_marker"]
      task = asyncio.create_task(_check_single_site(websocket, ready_url, service_name, semaphore, marker))
      tasks.append(task)
      await asyncio.sleep(0.2)
   results = await asyncio.gather(*tasks)
   # print(results)
   await websocket.send_json({"status" : "COMPLETED"})
   return results