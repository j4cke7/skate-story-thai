# Skate Story ภาษาไทย | Thai Translation Mod

[![Skate Story](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1263240/header.jpg)](https://store.steampowered.com/app/1263240/Skate_Story/)

ม็อดภาษาไทยสำหรับ **Skate Story บน Steam Windows build 21628663** เวอร์ชันม็อด 1.0.0

A Thai translation mod for Skate Story on Steam Windows. It adds Thai as a new in-game language, with Thai fonts and installation and uninstall instructions.

## [ดาวน์โหลดม็อดภาษาไทย (.zip)](https://github.com/j4cke7/skate-story-thai/releases/download/v1.0.0-build21628663/Skate-Story-Thai-build21628663.zip)

[รายละเอียดรุ่น](https://github.com/j4cke7/skate-story-thai/releases/tag/v1.0.0-build21628663) · [ไฟล์ตรวจสอบ SHA-256](https://github.com/j4cke7/skate-story-thai/releases/download/v1.0.0-build21628663/Skate-Story-Thai-build21628663.zip.sha256)

ดาวน์โหลด ZIP จากลิงก์ข้างบนเพื่อใช้งานม็อด ขนาดไฟล์ 1,692,256 ไบต์ หรือประมาณ 1.6 MiB

ม็อดเพิ่ม **ภาษาไทย** เป็นภาษาใหม่ในเกม ภาษาเดิมทุกภาษายังเลือกได้ตามปกติ แปลข้อความในตารางภาษาหลักของเกมครบ 2,304 รายการ ทั้งบทสนทนา ไอเทม และเมนู ข้อความบางส่วนที่อยู่นอกตารางนี้อาจยังเป็นภาษาอังกฤษ ฟอนต์ภาษาไทยรวมอยู่ในชุดม็อดแล้ว ไม่ต้องติดตั้งฟอนต์เพิ่ม

## วิธีติดตั้ง

1. ปิดเกมให้เรียบร้อย
2. แตกไฟล์ ZIP **ทั้งหมด** ไว้ในโฟลเดอร์เดียวกัน เช่น โฟลเดอร์บน Desktop ไม่จำเป็นต้องแตกลงโฟลเดอร์เกม
3. ดับเบิลคลิก `Install.cmd` แล้วรอให้ติดตั้งเสร็จ ตัวติดตั้งจะค้นหาโฟลเดอร์เกมใน Steam และสำรองไฟล์เดิมโดยอัตโนมัติ
4. เปิดเกม ไปที่ **Settings** แล้วเลือกภาษา **ภาษาไทย**

ตัวติดตั้งใช้ไฟล์ `.cmd` เรียกสคริปต์ PowerShell คุณอ่าน [ซอร์สโค้ด Patch.ps1](source/Patch.ps1) ได้ก่อนใช้งาน ส่วน `Status.cmd` ใช้ดูว่าตอนนี้ติดตั้งม็อดอยู่หรือไม่

## วิธีถอนม็อด

1. ปิดเกม
2. ดับเบิลคลิก `Uninstall.cmd` ในโฟลเดอร์ม็อด
3. เปิดเกมอีกครั้ง แล้วเลือกภาษาที่ต้องการใน Settings

เก็บโฟลเดอร์ม็อดไว้สำหรับถอนการติดตั้ง และอย่าลบไฟล์สำรอง `.skate-thai-original-21628663.bak` ที่ตัวติดตั้งสร้างไว้ในโฟลเดอร์ `SkateStory_Data`

## หากติดตั้งไม่สำเร็จ

- ตรวจว่าแตกไฟล์ ZIP ครบแล้วและปิดเกมอยู่
- หากการติดตั้งถูกขัดจังหวะ ให้ปิดเกมแล้วเรียก `Install.cmd` อีกครั้ง
- หากขึ้นคำเตือนว่ารุ่นเกมไม่ตรง ตัวติดตั้งจะติดตั้งต่อเมื่อไฟล์ที่ม็อดแก้ยังตรงกับต้นฉบับ หากข้อความแสดงผิดปกติ ให้ถอนด้วย `Uninstall.cmd`
- หากแจ้งว่าไฟล์เกมถูกแก้ไขหรือเสียหาย ให้คืนไฟล์ต้นฉบับก่อน ใน Steam คลิกขวาที่เกม แล้วเลือก **Properties > Installed Files > Verify integrity of game files** การตรวจนี้อาจคืนไฟล์ที่ม็อดอื่นแก้ไว้เป็นต้นฉบับด้วย

ชุดนี้ทดสอบกับ build 21628663 หาก Steam อัปเดตไฟล์ข้อมูลเกมแล้ว ม็อดรุ่นนี้จะติดตั้งไม่ได้ ให้รอม็อดรุ่นใหม่ ส่วน `Uninstall.cmd` ยังใช้ได้ และจะลบเฉพาะไฟล์สำรองของม็อด ไม่แตะไฟล์เกมรุ่นใหม่

### เมื่อตัวติดตั้งหาโฟลเดอร์เกมไม่พบ

ทำส่วนนี้เฉพาะเมื่อ `Install.cmd` แจ้งว่าหาเกมไม่พบ

1. ใน Steam คลิกขวาที่ Skate Story แล้วเลือก **Manage > Browse local files**
2. คัดลอกพาธจากแถบที่อยู่ของหน้าต่างโฟลเดอร์เกม
3. กลับไปโฟลเดอร์ม็อด คลิกแถบที่อยู่ พิมพ์ `powershell` แล้วกด Enter
4. วางคำสั่งด้านล่าง เปลี่ยนพาธในเครื่องหมายคำพูดเป็นพาธเกมที่คัดลอกมา แล้วกด Enter

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch.ps1 -Action Install -GameRoot "D:\SteamLibrary\steamapps\common\Skate Story"
```

## ตรวจสอบไฟล์ดาวน์โหลด

SHA-256 ของ `Skate-Story-Thai-build21628663.zip` คือ

```text
69b0f59fc504da4b6495aa299f6b28080bcc206a19ac22de97fd891e4d0558e1
```

ใน PowerShell ใช้คำสั่งนี้ โดยเปลี่ยนพาธให้ตรงกับไฟล์ที่ดาวน์โหลด แล้วเทียบค่า `Hash` กับค่าด้านบน

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath ".\Skate-Story-Thai-build21628663.zip"
```

## ซอร์สโค้ดและสัญญาอนุญาต

- [Patch.ps1](source/Patch.ps1), [Install.cmd](source/Install.cmd), [Uninstall.cmd](source/Uninstall.cmd) และ [Status.cmd](source/Status.cmd) เป็นซอร์สโค้ดของตัวติดตั้งและตัวถอนม็อด
- [สัญญาอนุญาตฟอนต์](licenses/) มีข้อกำหนดของฟอนต์ Trirong, Taviraj และ Mitr (SIL Open Font License 1.1) ที่รวมในชุดม็อด ฟอนต์ถูกดัดแปลงโดยเพิ่มรูปอักษรไทยที่ประกอบสระและวรรณยุกต์ไว้แล้ว เพื่อให้วรรณยุกต์ไม่ซ้อนทับสระในเกม
- [SHA256SUMS.txt](SHA256SUMS.txt) เก็บค่า SHA-256 สำหรับตรวจสอบไฟล์เผยแพร่

ชุดม็อดไม่มีไฟล์เกมต้นฉบับหรือ DLL ตัวติดตั้งสร้างไฟล์ภาษาไทยจากไฟล์ต้นฉบับในเครื่องของคุณ

ม็อดนี้เป็นงานแปลโดยแฟนเกม ไม่มีส่วนเกี่ยวข้องอย่างเป็นทางการกับผู้พัฒนาหรือผู้จัดจำหน่าย Skate Story
