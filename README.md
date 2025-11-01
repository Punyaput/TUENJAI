<div align="center">

<img src="assets/images/Logo_TUENJAI.png" alt="TuenJai Logo" width="150"/>

# 🧠 TuenJai (เตือนใจ)
**แอปช่วยดูแลและแจ้งเตือนคนที่คุณห่วงใย**

<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"/>
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android"/>
</p>

</div>

---

## 📖 ภาพรวมโปรเจกต์

**TuenJai (เตือนใจ)** เป็นแอปพลิเคชันสำหรับช่วยดูแลคนที่คุณห่วงใยร่วมกัน (Collaborative Care)  
ออกแบบมาสำหรับผู้ใช้ชาวไทยโดยเฉพาะ 🇹🇭  

โปรเจกต์นี้ถูกสร้างขึ้นสำหรับคลาสที่เน้นการออกแบบประสบการณ์ผู้ใช้ (UX) และ **Captology** (เทคโนโลยีเพื่อการโน้มน้าวใจ)  
โดยมีเป้าหมายเพื่อช่วยให้ "ผู้ดูแล" (Caretaker) สามารถจัดการและส่งการแจ้งเตือนไปยัง "ผู้รับการดูแล" (Care Receiver) เช่น ผู้สูงอายุ หรือผู้ที่มีปัญหาด้านความจำ ได้อย่างง่ายดายและมีประสิทธิภาพ

หัวใจหลักของแอปคือการแบ่งผู้ใช้ออกเป็น 2 บทบาท เพื่อสร้างประสบการณ์ที่เหมาะสมที่สุดสำหรับแต่ละฝ่าย

---

## ✨ ฟีเจอร์หลัก

### 1. ระบบสองบทบาท (User Roles)
- 👤 **ผู้ดูแล (Caretaker)**: สร้างกลุ่ม, จัดการสมาชิก, และสร้าง/แก้ไข/ลบงานทั้งหมด  
- 👥 **ผู้รับการดูแล (Care Receiver)**: หน้าจอเรียบง่าย เน้นดูงานและกดยืนยันเมื่อทำเสร็จ

### 2. ระบบยืนยันตัวตน (Authentication)
- เข้าสู่ระบบและสมัครใช้งานผ่าน **เบอร์โทรศัพท์ (OTP)**  
- ต้องตั้งค่าโปรไฟล์และเลือกบทบาทก่อนเข้าสู่หน้าหลัก

### 3. การจัดการกลุ่ม (Group Management)
- ผู้ดูแลสร้างกลุ่มใหม่ได้  
- เชิญสมาชิกผ่าน **รหัสเชิญ (Invite Code)** หรือ **QR Code**  
- ระบบ “คำขอเข้าร่วม” ที่ต้องได้รับการอนุมัติจากผู้ดูแล  
- แก้ไขข้อมูลกลุ่มและจัดการสมาชิกได้เต็มรูปแบบ  

### 4. การจัดการงาน (Task Management)
ประเภทของงาน:
- **Appointment (นัดหมาย)**  
- **Countdown (นับถอยหลัง)**  
- **Habit (กิจวัตร)** — ตั้งตารางรายวัน เช่น `08:00 ทานยา`, `12:00 ทานข้าว`

ผู้รับการดูแลสามารถกดยืนยันการทำงานได้โดยตรง

### 5. แดชบอร์ด (Dashboard)
หน้าหลักจะแตกต่างตามบทบาท:
- แสดงงานตามสถานะ เช่น  
  - วันนี้ (รอดำเนินการ)  
  - ผ่านไปแล้ว  
  - เสร็จสิ้น  
  - กิจกรรมวันนี้!  
  - สิ่งที่กำลังจะมาถึง

### 6. ระบบแจ้งเตือนอัจฉริยะ (Notification System) 🔔
ใช้ทั้ง **Push Notifications (Cloud Functions)** และ **Local Notifications**  

#### สำหรับผู้รับการดูแล:
- แจ้งเตือนเมื่อมีงานใหม่ / แก้ไข / ใกล้ถึงเวลา / ถึงเวลา / สรุปรายวัน  

#### สำหรับผู้ดูแล:
- แจ้งเตือนคำขอเข้ากลุ่ม / งานเสร็จ / งานพลาด / ถึงกำหนด  

#### สำหรับทุกคนในกลุ่ม:
- แจ้งเตือน 1 วันก่อนและในวัน Countdown

### 7. การจัดการโปรไฟล์และข้อมูล
- ตั้งค่า/แก้ไขโปรไฟล์  
- ลบบัญชี (Firestore + Auth)  
- ลบกลุ่มอัตโนมัติเมื่อไม่มีสมาชิก  
- หน้าข้อกำหนดการใช้งาน (ToS) และนโยบายความเป็นส่วนตัว (Privacy Policy)

---

## 🛠️ เทคโนโลยีที่ใช้

| หมวด | เทคโนโลยี |
|------|-------------|
| **Frontend** | Flutter |
| **Backend** | Firebase |
| **Database** | Cloud Firestore (NoSQL, Real-time) |
| **Authentication** | Firebase Authentication (Phone OTP) |
| **File Storage** | Firebase Storage |
| **Backend Logic** | Cloud Functions for Firebase (v2, TypeScript) |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Local Notifications** | flutter_local_notifications |
| **Security** | Firebase App Check (Play Integrity) & Firestore Rules |
| **Environment** | Flutter Flavors (dev/prod) |

**Key Packages**
- `image_picker` – เลือกรูป  
- `mobile_scanner` – สแกน QR Code  
- `qr_flutter` – สร้าง QR Code  
- `intl` – จัดการวันที่/เวลา  
- `markdown_widget` – แสดง ToS/Privacy Policy  

---

## 🚀 การติดตั้งและใช้งาน

โปรเจกต์นี้ใช้ **Flutter Flavors** เพื่อแยก dev/prod environment

### Clone Repository
```bash
git clone https://github.com/Punyaput/TUENJAI
cd tuenjai_project
```

---

## ⚙️ การตั้งค่า Firebase

### 1. สร้างโปรเจกต์ Firebase  
สร้างโปรเจกต์ Firebase **2 ตัว** สำหรับ **Development (dev)** และ **Production (prod)**  

ในแต่ละโปรเจกต์:
- เปิดใช้งาน **Authentication (Phone)**  
- เปิดใช้งาน **Cloud Firestore**, **Storage**, และ **App Check**

เพิ่ม Android app ลงในทั้งสองโปรเจกต์ โดยใช้ Package Name ที่ถูกต้อง เช่น  
- `com.yourdomain.tuenjai.dev`  
- `com.yourdomain.tuenjai`  

อย่าลืมเพิ่ม **SHA-1** และ **SHA-256** (ทั้ง debug และ release) ให้ครบ

---

### 2. เพิ่มไฟล์ Config  
วางไฟล์ `google-services.json` ของแต่ละโปรเจกต์ลงในตำแหน่งต่อไปนี้:

```bash
android/app/src/dev/google-services.json
android/app/src/prod/google-services.json
```

---

### 3. สร้าง Firebase Options  
ใช้คำสั่ง `flutterfire configure` เพื่อสร้างไฟล์ options แยกตาม environment  

```bash
# สำหรับ dev
flutterfire configure
# จะสร้าง: lib/firebase_options.dart => เปลี่ยนชื่อเป็น firebase_options_dev.dart

# สำหรับ prod
flutterfire configure
# จะสร้าง: lib/firebase_options.dart => เปลี่ยนชื่อเป็น firebase_options_prod.dart
```

> 💡 หมายเหตุ:  
> ก่อนรันคำสั่งแต่ละครั้ง ให้วางไฟล์ `google-services.json` ของ environment นั้น ๆ ไว้ใน `android/app/`

---

### 4. ติดตั้ง Packages  
```bash
flutter pub get
```

---

### 5. Deploy Cloud Functions  

ตั้งค่า Firebase CLI aliases:  
```bash
firebase use --add
```

ติดตั้ง dependencies และ deploy:  
```bash
cd functions
npm install

firebase use dev
firebase deploy --only functions
```

> ทำซ้ำขั้นตอนนี้สำหรับ **prod**

---

### 6. รันแอป  
```bash
# Development build
flutter run --flavor dev --target lib/main_dev.dart

# Production build
flutter run --flavor prod --target lib/main_prod.dart
```
