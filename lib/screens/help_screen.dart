// lib/screens/help_screen.dart
import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // Helper to create styled ExpansionTiles
  Widget _buildHelpSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.secondary),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
            fontSize: 16,
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
        children: children,
      ),
    );
  }

  // Helper for individual Q&A items
  Widget _buildQAItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Q: $question",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "A: $answer",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ช่วยเหลือและคำถามที่พบบ่อย'),
      ), // "Help & FAQ"
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHelpSection(
            context: context,
            title: 'เริ่มต้นใช้งาน', // Getting Started
            icon: Icons.flag_outlined,
            children: [
              _buildQAItem(
                'ผู้ดูแล (Caretaker) กับ ผู้รับการดูแล (Care Receiver) ต่างกันอย่างไร?',
                'ผู้ดูแลสามารถสร้างกลุ่ม, เชิญสมาชิก, และสร้าง/มอบหมายงานทั้งหมดได้. ผู้รับการดูแลจะมีหน้าจอที่ง่ายกว่า เน้นการดูและทำงานที่ได้รับมอบหมายให้เสร็จ.',
              ),
              _buildQAItem(
                'ฉันจะลงทะเบียน/เข้าสู่ระบบได้อย่างไร?',
                'แอปใช้การยืนยันตัวตนผ่านหมายเลขโทรศัพท์. เพียงป้อนหมายเลขโทรศัพท์ของคุณ จากนั้นกรอกรหัส OTP 6 หลักที่ได้รับทาง SMS เพื่อเข้าสู่ระบบ.',
              ),
              _buildQAItem(
                'ฉันจะตั้งค่าโปรไฟล์ได้อย่างไร?',
                'สำหรับผู้ใช้ใหม่ หลังจากยืนยัน OTP คุณจะไปที่หน้าตั้งค่าโปรไฟล์. คุณสามารถตั้งชื่อผู้ใช้, คำอธิบาย (ไม่บังคับ), และเลือกรูปโปรไฟล์ได้ที่นี่.',
              ),
            ],
          ),
          _buildHelpSection(
            context: context,
            title: 'กลุ่ม', // Groups
            icon: Icons.group_outlined,
            children: [
              _buildQAItem(
                'ฉันจะสร้างกลุ่มได้อย่างไร? (สำหรับผู้ดูแล)',
                'ไปที่หน้า "กลุ่ม" และแตะปุ่ม "+". เลือก "สร้างกลุ่ม" และกรอกชื่อกับคำอธิบายกลุ่ม. ระบบจะสร้างรหัสเชิญ 8 หลักให้โดยอัตโนมัติ.',
              ),
              _buildQAItem(
                'ฉันจะเชิญคนเข้ากลุ่มได้อย่างไร? (สำหรับผู้ดูแล)',
                'ไปที่หน้า "กลุ่ม" -> เลือกกลุ่มที่ต้องการ -> แตะไอคอนฟันเฟือง (ตั้งค่า). ในหน้าตั้งค่ากลุ่ม คุณจะเห็นรหัสเชิญและ QR Code. แสดง QR Code ให้เพื่อนสแกน หรือคัดลอกรหัสส่งให้เพื่อนได้เลย.',
              ),
              _buildQAItem(
                'ฉันจะเข้าร่วมกลุ่มได้อย่างไร?',
                'ไปที่หน้า "กลุ่ม" และแตะปุ่ม "+". เลือก "เข้าร่วมกลุ่ม". คุณสามารถกรอกรหัสเชิญ 8 หลัก หรือแตะปุ่ม "สแกน QR Code" เพื่อใช้กล้องสแกนรหัสจากผู้ดูแลได้. คำขอเข้าร่วมของคุณจะถูกส่งไปให้ผู้ดูแลอนุมัติก่อน.',
              ),
              _buildQAItem(
                'ฉันจะจัดการสมาชิก/คำขอเข้าร่วมได้อย่างไร? (สำหรับผู้ดูแล)',
                'ไปที่หน้าตั้งค่ากลุ่ม คุณสามารถดู "คำขอเข้าร่วม" เพื่อกดอนุมัติหรือปฏิเสธได้. และใน "รายชื่อสมาชิก" คุณสามารถกดไอคอนถังขยะเพื่อนำสมาชิกออกจากกลุ่มได้.',
              ),
            ],
          ),
          _buildHelpSection(
            context: context,
            title: 'งานและการแจ้งเตือน', // Tasks & Reminders
            icon: Icons.list_alt_outlined,
            children: [
              _buildQAItem(
                'ฉันจะสร้างงานได้อย่างไร? (สำหรับผู้ดูแล)',
                'ไปที่หน้า "กลุ่ม" -> เลือกกลุ่มที่ต้องการ -> แตะปุ่ม "+" สีฟ้า. เลือกประเภทงาน (นัดหมาย, นับถอยหลัง, กิจวัตร), กรอกรายละเอียด, เลือกวัน/เวลา (ถ้ามี), และเลือกว่าจะมอบหมายให้ใคร.',
              ),
              _buildQAItem(
                'ฉันจะแก้ไขงานหรือตารางกิจวัตรได้อย่างไร? (สำหรับผู้ดูแล)',
                'ในหน้ารายละเอียดกลุ่ม, คุณสามารถแตะไอคอนดินสอ (✎) ข้างๆ งานเพื่อนแก้ไขรายละเอียดทั่วไป. สำหรับกิจวัตร, กดปุ่ม "แก้ไขตารางเวลา" ในหน้าสร้าง/แก้ไขงาน เพื่อจัดการรายการเวลาและชื่องานย่อยในแต่ละวัน.',
              ),
              _buildQAItem(
                'ฉันจะทำเครื่องหมายว่าทำงานเสร็จแล้วได้อย่างไร? (สำหรับผู้รับการดูแล)',
                'ในหน้าหลัก, งานประเภทนัดหมายและกิจวัตรสำหรับวันนี้จะมีปุ่มให้กดทำเครื่องหมายว่าเสร็จสิ้น. คุณยังสามารถกดปุ่ม "ทำเสร็จแล้ว" จากการแจ้งเตือนบนหน้าจอล็อกหรือแถบแจ้งเตือนเมื่อถึงเวลางานได้.',
              ),
            ],
          ),
          _buildHelpSection(
            context: context,
            title: 'การแจ้งเตือน', // Notifications
            icon: Icons.notifications_outlined,
            children: [
              _buildQAItem(
                'การแจ้งเตือนทำงานอย่างไร?',
                'แอปจะส่งการแจ้งเตือนเมื่อมีงานใหม่, งานถูกแก้ไข, งานเสร็จสิ้น, มีคนขอเข้าร่วมกลุ่ม, เมื่อถึงเวลานัดหมาย/กิจวัตร (แจ้งเตือนล่วงหน้า 1 ชั่วโมง และเมื่อถึงเวลาพอดี), และแจ้งเตือนสำหรับวันนับถอยหลัง (แจ้งเตือนล่วงหน้า 1 วัน และในวันนั้น).',
              ),
              _buildQAItem(
                'ทำไมฉันไม่ได้รับการแจ้งเตือน?',
                'โปรดตรวจสอบการตั้งค่าโทรศัพท์ของคุณ:\n1. แอปได้รับอนุญาตให้ส่งการแจ้งเตือนหรือไม่ (Settings > Apps > TuenJai > Notifications)?\n2. โทรศัพท์อยู่ในโหมดห้ามรบกวน (Do Not Disturb) หรือไม่?\n3. มีการตั้งค่าการประหยัดแบตเตอรี่ที่เข้มงวดเกินไปหรือไม่ (ลองตั้งค่าให้ TuenJai และ Google Play Services ไม่ถูกจำกัดการทำงานพื้นหลัง)?\n4. คุณมีการเชื่อมต่ออินเทอร์เน็ตที่เสถียรหรือไม่?',
              ),
            ],
          ),
          _buildHelpSection(
            context: context,
            title: 'บัญชี', // Account
            icon: Icons.account_circle_outlined,
            children: [
              _buildQAItem(
                'ฉันจะแก้ไขข้อมูลโปรไฟล์/รูปภาพได้อย่างไร?',
                'ไปที่หน้า "ตั้งค่า" -> "ตั้งค่าโปรไฟล์" | คุณสามารถแก้ไขชื่อ, คำอธิบาย, และอัปโหลดรูปโปรไฟล์ใหม่ได้ที่นี่.',
              ),
              _buildQAItem(
                'ฉันจะลบบัญชีได้อย่างไร?',
                'ไปที่หน้า "ตั้งค่า" -> "ลบบัญชี" | โปรดยืนยันการลบ ระบบจะลบข้อมูลบัญชีและข้อมูลผู้ใช้ของคุณออกจากระบบอย่างถาวร.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
