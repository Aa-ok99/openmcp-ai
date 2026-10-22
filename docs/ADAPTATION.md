# 🔀 สิ่งที่เปลี่ยนจากต้นฉบับ `debian--ai`

โปรเจกต์นี้เริ่มจาก [`Aa-ok99/debian--ai`](https://github.com/Aa-ok99/debian--ai) โดยใช้ `4.sh` เป็นฐาน (เป็นเวอร์ชันที่มี UI/animation ครบที่สุดในชุด) แล้วปรับให้ทำงานกับ **Ubuntu บน Termux** ได้จริง

---

## 🐛 บั๊กที่พบในต้นฉบับและแก้แล้ว

### 1. ชื่อแพ็กเกจ npm ผิด — ติดตั้งเวอร์ชันเก่า

ต้นฉบับใช้ `npm install -g opencode-ai` ทั้งที่แพ็กเกจนั้นค้างที่ **v1.19.4** และไม่ได้ถูกพัฒนาต่อ ส่วนแพ็กเกจที่ใช้งานจริงคือ `@opencode/cli` (v2.x)

```diff
- npm install -g opencode-ai
+ npm install -g @opencode/cli@latest
```

พบทั้งใน `setup.sh`, `2.sh`, `3.sh`, `4.sh` — รวม 12 จุด

### 2. `bar_run()` เป็น dead code

ฟังก์ชัน progress bar ถูกเขียนไว้ 47 บรรทัดแต่ **ไม่เคยถูกเรียก** ในไฟล์ใดเลย มีแต่ `spinner_run()` ที่ถูกใช้จริง

→ รวมเข้ากับ `scripts/lib/ui.sh` และเรียกใช้จริงในขั้นตอนที่ใช้เวลานาน

### 3. ตัวแปร `WHITE` ไม่เคยถูกนิยาม

บรรทัด 97 ของ `4.sh` ใช้ `${WHITE:-}` — ปิดบั๊กด้วย default expansion แต่ตัวแปรไม่มีอยู่จริง

→ นิยาม `WHITE` ให้ครบทั้ง 16 สีใน `scripts/lib/ui.sh`

### 4. ลอกอิกโค้ดซ้ำซ้อนใน `bar_run`

บรรทัด 95-102 พิมพ์บาร์ แล้วพิมพ์ซ้ำอีกชุดหนึ่ง พร้อมคอมเมนต์ว่า *"Above line has extra complexity; keep simple"* — โค้ดที่ไม่ได้ทำงานเป็นผลลัพธ์

→ เขียนใหม่ให้เป็นบาร์เดียว

---

## 🩹 บั๊กที่เจอตอนพอร์ต (แก้แล้ว)

### 1. `nodejs-lts` ไม่มีอยู่จริงบน Ubuntu

`apt-get install nodejs-lts` ตายด้วย *Unable to locate package* แล้ว `set -e` ปิดสคริปต์ทั้งตัว
Ubuntu 26.04 มี `nodejs` v22 อยู่แล้ว — เปลี่ยนเป็น `nodejs npm` และเพิ่มการ์ดความสูง:
ถ้า Node เก่ากว่า v22 จะดันผ่าน NodeSource เพราะ Claude Code บังคับ `>=22`

### 2. `PURGE` ไม่ถูกนิยาม → `--uninstall` พัง

`set -u` ทำให้ `[ "$PURGE" -eq 1 ]` ในเส้นทาง `--uninstall` ตายทันทีถ้าไม่ได้ส่ง `--purge` มาด้วย

### 3. `sed` ตอนถอนกวาดบรรทัดเกิน

`sed '/marker/,+4d'` ลบบล็อกที่ยาวแค่ 2 บรรทัด → กินบรรทัดของผู้ใช้ไป 2 บรรทัด
เปลี่ยนเป็น `,+1d` และเช็คว่าไฟล์มีอยู่ก่อน

### 4. `--dry-run` ตายถ้ายังไม่ได้ติดตั้งอะไร

หลัง `run apt-get install` สคริปต์เช็ค `have node` จากระบบจริง → dry-run บนเครื่องเปล่าจึง `exit 1`
เพิ่มการข้ามการตรวจสอบหลังติดตั้งเมื่อเป็น dry-run (และไม่ต้อง root สำหรับ `--dry-run` / `--verify-only`)

### 5. กรอบ banner แตกกับข้อความไทย

เดิมนับทุก codepoint ไทยเป็นความกว้าง 2 → บรรทัดหัวเรื่องล้นกรอบ
ที่ถูกคือ Thai base = 1, สระ/วรรณยุกต์ซ้อน (Mn) = 0 — แต่ `า`/`ำ` เป็นสระมีระยะ ต้องนับ 1
และ `banner()` ขยายกรอบเองถ้าหัวเรื่องยาวเกิน

### 6. `blocks` เป็น dead code

ตัวแปรใน `bar_run()` ไม่เคยถูกใช้ — ลบทิ้ง (ShellCheck จับได้)

---

## 🔄 การปรับให้รองรับ Ubuntu

| มิติ | ต้นฉบับ | openmcp-ai |
| --- | --- | --- |
| distro | Debian | **Ubuntu 26.04** |
| จุดเริ่มรัน | Termux → proot → Debian (ทั้งหมดในสคริปต์เดียว) | **แยก 2 ชั้น** — `install.sh` (Termux) + `ubuntu-setup.sh` (ใน container) |
| Node.js | NVM v0.40.1 + `nvm install node` | **ตรวจของเดิมก่อน** ถ้าขาดค่อย `apt install nodejs npm` (ไม่มีแพ็กเกจ `nodejs-lts` บน Ubuntu) + ดันเป็น v22 ผ่าน NodeSource ถ้าเก่าเกิน |
| npm global | ไม่กำหนด (ได้ root ของ user ปัจจุบัน) | บังคับ `npm config set prefix /usr/local` ให้อยู่ใน PATH ของทุก user |
| aliases | ทั้งหมด wrap ผ่าน `proot-distro login debian` | **native ใน Ubuntu** — ไม่ต้องผ่าน proot อีก |
| Claude Code | `@gitlawb/openclaude` | **`@anthropic-ai/claude-code`** (แพ็กเกจทางการ) |
| Bun | อยู่ใน README แต่ไม่มีในสคริปต์ | ติดตั้งจริง + **ตรวจผล** แล้วข้ามถ้ารันใน proot ไม่ได้ |
| `u_root` symlink | README บอกให้สร้างเอง | สร้างให้อัตโนมัติ |

### เหตุผลที่ต้องแยก 2 ชั้น

`proot-distro` ปฏิเสธการทำงานเมื่ออยู่ใน proot session อยู่แล้ว:

```
Error: attempted to run proot-distro in a proot session.
Please check your system configuration to ensure that this program does not
run under any other proot instance.
```

ถ้ารวมเป็นสคริปต์เดียวแบบต้นฉบับ จะไม่มีทางรู้ได้ว่าตอนนี้ "อยู่ฝั่ง Termux" หรือ "อยู่ใน container" — แยกชั้นจึงแก้ปัญหานี้ได้ตรงจุด

---

## ➕ สิ่งที่เพิ่มเข้ามาใหม่

### MCP servers

เพิ่ม `scripts/mcp-setup.sh` ที่ตั้งค่า:

- `filesystem` — อ่าน/เขียนไฟล์ใน `$HOME`
- `playwright` — ควบคุมเบราว์เซอร์ headless

พร้อมติดตั้งเบราว์เซอร์ให้ถูกเวอร์ชันด้วยวิธีหา `playwright-core/cli.js` ที่อยู่ใน npx cache **ของแพ็กเกจ `@playwright/mcp` ตัวเดียวกัน** แล้วสั่ง `install chromium` + `install-deps chromium` ผ่านตัวนั้น — การติดตั้งผ่าน Playwright รุ่นอื่นอาจได้ revision ที่ไม่ตรงกับที่ MCP server คาดไว้

### OpenCode config

- `assets/opencode.json` — timeout, permission rules, agent `reviewer`, command `/review`
- `assets/cli.json` — ค่า TUI
- merge แบบไม่ทับค่าเดิมของผู้ใช้ (ใช้ `setdefault`)

### Skills

- `code-review` — ตรวจโค้ด: correctness, security, เทสต์ที่หายไป
- `mcp-free` — playbook ติดตั้ง/แก้ปัญหา MCP server ฟรี พร้อม `scripts/check-mcp.sh` ที่ตรวจทั้งสถานะและ config

### ความปลอดภัยของสคริปต์

| ฟีเจอร์ | ต้นฉบับ | openmcp-ai |
| --- | --- | --- |
| `--dry-run` | ไม่มี | มี — ดูแผนโดยไม่แตะระบบ |
| `--uninstall` | ไม่มี | มี — ถอน config, skills, aliases, cheatsheet (เก็บ `.bak` ไว้) |
| `--purge` | ไม่มี | มี — ถอน OpenCode / Claude Code / Bun ด้วย (ต้องสั่งเพิ่ม) |
| ถามก่อนอัปเดต | ไม่มี | มี — `confirm()` ก่อนอัปเดตแพ็กเกจที่มีอยู่แล้ว |
| เงื่อนไขข้าม | ไม่มี | `NO_COLOR`, `OPENMCP_ASSUME_YES`, `OPENMCP_DIR`, `OPENMCP_DISTRO` |
| animation เมื่อไม่ใช่ TTY | ไม่มี | มี — CI/pipe จะได้ plain text |

---

## 📦 โค้ดที่ยกมาจากต้นฉบับ

- ฟังก์ชัน UI (`grad`, `log`, `ok`, `warn`, `err`) — คงรูปแบบสีและสไตล์เดิม
- spinner และ progress bar — ปรับให้ทำงานถูกต้อง
- โครงสร้าง cheat sheet และ alias — เขียนใหม่ให้ตรงกับ Ubuntu
