<div align="center">

# 🌸 openmcp-ai

**ติดตั้ง OpenCode AI + MCP servers + Claude Code บน Termux ผ่าน Ubuntu (proot-distro)**

<p align="center">
  <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/opencode.svg" width="60" height="60" alt="OpenCode"/>
  <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/github.svg" width="60" height="60" alt="GitHub"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/STATUS-ACTIVE-FF1493?style=for-the-badge&logo=github&logoColor=white&labelColor=FF69B4&color=FF1493" alt="Status Active"/>
  <img src="https://img.shields.io/badge/UBUNTU-26.04-FF6B9D?style=for-the-badge&logo=ubuntu&logoColor=white&labelColor=FFB6C1" alt="Ubuntu 26.04"/>
  <img src="https://img.shields.io/badge/NODE-22.x-FF1493?style=for-the-badge&logo=nodedotjs&logoColor=white&labelColor=FFB6C1" alt="Node 22"/>
  <img src="https://img.shields.io/badge/MCP-2-FF1493?style=for-the-badge&logo=modelcontextprotocol&logoColor=white&labelColor=FF69B4" alt="MCP"/>
</p>

</div>

---

## ❓ ทำอะไรได้

คำสั่งเดียวจบ — ตั้งค่าทุกอย่างที่จำเป็นสำหรับ AI coding agent บนเครื่อง Android:

| ส่วน | รายละเอียด |
| --- | --- |
| **OpenCode AI** | `@opencode/cli` (แพ็กเกจปัจจุบัน) ติดตั้งแบบ global |
| **Claude Code** | `@anthropic-ai/claude-code` |
| **Node.js + npm** | ตรวจสอบก่อน ถ้ายังไม่มีค่อยติดตั้งผ่าน `apt` — ต้องเป็น **v22 ขึ้นไป** เพราะ Claude Code บังคับ (ถ้าเก่ากว่าจะดันผ่าน NodeSource ให้อัตโนมัติ) |
| **Bun** | ติดตั้งจาก `bun.sh` (ข้ามอัตโนมัติถ้ารันใน proot ไม่ได้) |
| **MCP servers** | `filesystem` + `playwright` (headless chromium) |
| **OpenCode config** | `opencode.json` + `cli.json` + permission rules |
| **Skills** | `code-review` + `mcp-free` |
| **Aliases + cheat sheet** | `~/.opencode_aliases` และ `~/OPCODE-CHEATSHEET.txt` |

---

## ⚡ ติดตั้ง

```bash
curl -fsSL https://raw.githubusercontent.com/Aa-ok99/openmcp-ai/main/install.sh | bash
```

หรือ clone มาแล้วรันเอง (แนะนำ ถ้าอยากดูโค้ดก่อน):

```bash
git clone https://github.com/Aa-ok99/openmcp-ai.git
bash openmcp-ai/install.sh
```

ใช้เวลาประมาณ 3-8 นาที ขึ้นอยู่กับความเร็วอินเทอร์เน็ตและขนาด container

---

## 🏗️ โครงสร้าง 2 ชั้น

สคริปต์แยกเป็นสองชั้น เพราะ `proot-distro` **รันได้เฉพาะฝั่ง Termux เท่านั้น** — ถ้าอยู่ใน proot session แล้วเรียก `proot-distro` จะ error ทันที

```
📱 Termux (Android)                    🐧 Ubuntu container (proot)
┌──────────────────────────┐            ┌──────────────────────────┐
│ install.sh               │            │ scripts/ubuntu-setup.sh  │
│  • ติดตั้ง proot-distro  │  ────────► │  • apt + Node + Bun      │
│  • เตรียม container      │  login     │  • OpenCode + Claude     │
│  • alias ฝั่ง Termux     │  ubuntu    │  • MCP + skills          │
└──────────────────────────┘            │  • aliases + cheatsheet  │
                                        └──────────────────────────┘
```

> `~/.openmcp` ของ Termux ถูก bind-mount เข้า container ที่ path เดิม ทั้งสองชั้นจึงอ่านไฟล์ชุดเดียวกันได้ ไม่ต้อง copy

---

## 🚀 ใช้งาน

```bash
u          # เข้า Ubuntu container
opencode   # เปิด OpenCode
```

ภายใน container มี alias ให้ใช้:

| Alias | ทำอะไร |
| --- | --- |
| `oc` / `oc-v` / `oc-h` | เปิด OpenCode / เช็คเวอร์ชัน / ดู help |
| `oc-mcp` | ดูสถานะ MCP servers |
| `oc-mcp-check` | ตรวจสอบ MCP + config ทั้งหมด |
| `cc` / `cc-v` | เปิด Claude Code / เช็คเวอร์ชัน |
| `node-version` | เช็ค Node + npm |
| `update-opencode` | อัปเดต OpenCode |
| `update-all` | อัปเดตทั้ง OpenCode และ Claude Code |
| `show-aliases` | แสดง alias ทั้งหมด |

ฝั่ง Termux มี `u` (เข้า container), `c` (ดูไฟล์ Termux), `u-list`, `openmcp-update`

คู่มือฉบับเต็ม: `cat ~/OPCODE-CHEATSHEET.txt`

---

## 🔌 MCP servers

| Server | ทำอะไร | เรียกใช้ |
| --- | --- | --- |
| `filesystem` | อ่าน/เขียนไฟล์ในโฮมไดเรกทอรี | `npx -y @modelcontextprotocol/server-filesystem ~` |
| `playwright` | ควบคุมเบราว์เซอร์สำหรับทดสอบเว็บ | `npx -y @playwright/mcp --browser chromium --headless --no-sandbox --isolated` |

ตรวจสอบสถานะ:

```bash
opencode mcp list
bash ~/.config/opencode/skills/mcp-free/scripts/check-mcp.sh ~
```

---

## ⚙️ ตัวเลือก

```bash
install.sh --dry-run       # แสดงแผนทั้งหมดโดยไม่แตะระบบ (ไม่ต้อง root)
install.sh --skip-mcp      # ข้าม MCP servers และ skills
install.sh --uninstall     # ถอน config, skills, aliases, cheatsheet
install.sh --uninstall --purge   # ถอนด้วย OpenCode, Claude Code และ Bun
install.sh --distro ubuntu # ระบุ distro อื่น
install.sh --repo-dir DIR  # ใช้ repo ที่ clone ไว้แล้ว แทน ~/.openmcp
```

ตัวแปรสภาพแวดล้อม: `OPENMCP_DIR` (ตำแหน่งโค้ด), `OPENMCP_DISTRO`, `OPENMCP_ASSUME_YES`, `NO_COLOR`

---

## 📂 โครงสร้างโปรเจกต์

```
openmcp-ai/
├── install.sh                 ชั้นนอก - Termux
├── scripts/
│   ├── ubuntu-setup.sh        ชั้นใน - Ubuntu
│   ├── mcp-setup.sh           MCP servers + config + skills
│   └── lib/ui.sh              UI helpers ร่วม
├── assets/
│   ├── opencode.json          เทมเพลต config
│   ├── cli.json               เทมเพลต TUI
│   └── skills/                code-review, mcp-free
├── tests/
│   └── smoke.sh               ชุดทดสอบ (ไม่ต้องใช้มือถือ)
├── docs/
│   ├── TROUBLESHOOTING.md
│   └── ADAPTATION.md          สิ่งที่เปลี่ยนจากต้นฉบับ debian--ai
└── .github/workflows/ci.yml   ShellCheck + smoke tests บน GitHub
```

---

## 🧪 ทดสอบ

ไม่ต้องมีมือถือก็เช็คได้ — ทุกอย่างรันใน HOME ชั่วคราว ไม่แตะระบบจริง:

```bash
bash tests/smoke.sh
```

ตรวจให้ครบทุกจุด: ทุกสคริปต์ parse ผ่าน, JSON valid, `--dry-run` ไม่เขียนอะไรลงดิสก์,
`--uninstall` ไม่กินบรรทัดอื่นใน `.bashrc`, banner ตรงกรอบแม้มีข้อความไทย,
และแพ็กเกจที่ไม่มีอยู่จริง (`nodejs-lts`) ไม่หลุดกลับมา

ตรวจ config กับ schema จริงของ OpenCode ด้วย (ต้องมีเน็ต + `jsonschema`):

```bash
SMOKE_SCHEMA=1 bash tests/smoke.sh
```

Lint ด้วย ShellCheck:

```bash
shellcheck -x -S warning install.sh scripts/*.sh scripts/lib/*.sh \
  assets/skills/*/scripts/*.sh tests/smoke.sh
```

CI รันทั้งสองอย่างให้อัตโนมัติทุก push ที่ `main`

---

## 🙏 ที่มา

โปรเจกต์นี้พัฒนาต่อยอดจาก **[Aa-ok99/debian--ai](https://github.com/Aa-ok99/debian--ai)** โดยปรับให้รองรับ Ubuntu จริง, แก้ชื่อแพ็กเกจ npm ที่ล้าสมัย, เพิ่ม MCP servers และ skills

ดูรายละเอียดการเปลี่ยนแปลงทั้งหมดได้ที่ [`docs/ADAPTATION.md`](docs/ADAPTATION.md)

---

## 📄 License

MIT — ดูที่ [LICENSE](LICENSE)

<sub>Repo by @Aa-ok99 | OpenCode is open source</sub>
