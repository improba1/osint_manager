# 🎛️ OSINT Manager

A multi-vector asynchronous open-source intelligence (OSINT) framework designed for concurrent reconnaissance across phone numbers, email addresses, and usernames.

---

## ⚙️ Core Modules & Features

* **📞 Phone Intelligence (`phone_checker.py`):** Parses and normalizes numbers using international standard layers. Executes direct MTProto queries for Telegram mapping, builds secure native URI deep-links (Viber/WhatsApp) to prevent account bans, and automates Google Dorks generation for global web footprinting.
* **📧 Email Verification Matrix (`email_checker.py`):** Performs deep asynchronous mailbox evaluation via MX-record resolution, structural syntax verification, and historical breach lookup. Features an integrated pre-filtering pipeline that tests targets against a local database of ephemeral providers (`disposable_email_blocklist.conf`).
* **👤 Identity & Handle Auditing (`name_checker.py`):** Runs parallel nickname queries across a multitude of public indices, social registries, and developer ecosystems to trace target aliases.

---

## 📦 Protocol Layer & Technical Stack

The tool leverages a diversified networking stack to optimize throughput while bypassing standard web-scraping defensive wrappers:

* **Asynchronous Engines:** `asyncio` & `trio` for robust non-blocking execution pipelines and nursery-led concurrency.
* **Network & Anti-Spam Defenses:** Powered by `curl_cffi` for advanced TLS/JA3 browser fingerprint impersonation (Chrome) and `httpx` for standard concurrent HTTP polling.
* **API & Core Layers:** Native cryptographic MTProto connection handling via `Telethon`, asynchronous DNS resolution via `dnspython`, and `python-phonenumbers` (Google's libphonenumber port).

---

## 🔐 Compliance & Security Manifesto

⚠️ Notice: This application is engineered exclusively for authorized auditing, institutional penetration testing, and digital footprint analysis. The operator is fully accountable for keeping actions within the scope of local data privacy ordinances and the target platform's respective Terms of Service (ToS).
