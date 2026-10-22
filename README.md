<div align="center">

# 🌸 openmcp-ai

**ติดตั้ง OpenCode + MCP servers + Claude Code บน Termux ผ่าน Ubuntu (proot-distro)**

<p align="center">
  <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/opencode.svg" width="56" height="56" alt="OpenCode"/>
  <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/anthropic.svg" width="56" height="56" alt="Claude Code"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/STATUS-ACTIVE-FF1493?style=for-the-badge&logo=github&logoColor=white&labelColor=FF69B4&color=FF1493" alt="Status Active"/>
  <img src="https://img.shields.io/badge/UBUNTU-26.04-FF6B9D?style=for-the-badge&logo=ubuntu&logoColor=white&labelColor=FFB6C1" alt="Ubuntu 26.04"/>
  <img src="https://img.shields.io/badge/NODE-22.x-FF1493?style=for-the-badge&logo=nodedotjs&logoColor=white&labelColor=FFB6C1" alt="Node 22"/>
  <img src="https://img.shields.io/badge/MCP-2-FF1493?style=for-the-badge&logo=modelcontextprotocol&logoColor=white&labelColor=FF69B4" alt="MCP 2 servers"/>
  <img src="https://img.shields.io/badge/LICENSE-MIT-FF1493?style=for-the-badge&labelColor=FFB6C1" alt="License MIT"/>
</p>

</div>

---

## ❓ ทำอะไรได้

คำสั่งเดียวจบ — ตั้งค่าครบสำหรับ AI coding agent บน Android:

| ส่วน | รายละเอียด |
| --- | --- |
| **OpenCode** | `@opencode/cli` แพ็กเกจปัจจุบัน ติดตั้งแบบ global |
| **Claude Code** | `@anthropic-ai/claude-code` |
| **Node.js + npm** | ตรวจก่อน ถ้ายังไม่มีจึงติดตั้งผ่าน `apt` — ต้องเป็น **v22 ขึ้นไป** เพราะ Claude Code ต้องใช้ (ถ้าเก่ากว่า จะอัปเกรดผ่าน NodeSource ให้อัตโนมัติ) |
| **Bun** | ติดตั้งจาก `bun.sh` (ข้ามอัตโนมัติถ้ารันใน proot ไม่ได้) |
| **MCP servers** | `filesystem` + `playwright` (headless chromium) |
| **OpenCode config** | `opencode.json` + `cli.json` + permission rules |
| **Skills** | `code-review` + `mcp-free` |
| **Aliases + cheat sheet** | `~/.opencode_aliases` และ `~/OPCODE-CHEATSHEET.txt` |

---

## ✅ สิ่งที่ต้องมี

- **Android 7 ขึ้นไป** + [Termux จาก F-Droid](https://f-droid.org/packages/com.termux/) — เวอร์ชันใน Play Store เลิกอัปเดตแล้ว
- **พื้นที่ว่างอย่างน้อย 3 GB** สำหรับ container, Node modules และเบราว์เซอร์ของ Playwright
- **อินเทอร์เน็ต** สำหรับดาวน์โหลด container และแพ็กเกจ npm
- **ไม่ต้อง root เครื่อง** และไม่ต้องติดตั้ง Ubuntu เอง — สคริปต์จัดการให้ผ่าน `proot-distro`
- ใช้เวลาราว **5–15 นาที** ขึ้นอยู่กับความเร็วอินเทอร์เน็ตและสเปกเครื่อง

---

## ⚡ ติดตั้ง

```bash
curl -fsSL https://raw.githubusercontent.com/Aa-ok99/openmcp-ai/main/install.sh | bash
```

หรือโคลน repo แล้วรันเอง (แนะนำ ถ้าอยากตรวจโค้ดก่อน):

```bash
git clone https://github.com/Aa-ok99/openmcp-ai.git
bash openmcp-ai/install.sh
```

> ถ้ารันจากโฟลเดอร์ที่โคลนมามี `.git` สคริปต์จะใช้โฟลเดอร์นั้นเป็นที่ทำงานเลย ไม่โคลนซ้ำลง `~/.openmcp`
> ส่วนการติดตั้งผ่าน `curl | bash` จะใช้ `~/.openmcp`
>
> อยากดูก่อนว่าสคริปต์จะทำอะไร ใช้ `bash install.sh --dry-run` — ไม่แตะระบบและไม่ต้อง root

---

## 🏗️ โครงสร้าง 2 ชั้น

สคริปต์แยกเป็นสองชั้น เพราะ `proot-distro` **รันได้เฉพาะฝั่ง Termux** — ถ้าอยู่ใน proot session แล้วเรียก `proot-distro` จะ error ทันที

```text
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

### Alias ภายใน container

| Alias | ทำอะไร |
| --- | --- |
| `oc` / `oc-h` / `oc-v` | เปิด OpenCode / ดู help / เช็คเวอร์ชัน |
| `oc-mcp` | ดูสถานะ MCP servers |
| `oc-mcp-check` | ตรวจ MCP + config ทั้งหมด |
| `cc` / `cc-v` | เปิด Claude Code / เช็คเวอร์ชัน |
| `node-version` | เช็ค Node + npm |
| `npm-ls` / `npm-root` | ดูแพ็กเกจ global / ดูตำแหน่ง `node_modules` |
| `update-opencode` / `reinstall-opencode` | อัปเดต / ถอนแล้วติดตั้ง OpenCode ใหม่ |
| `update-claude` | อัปเดต Claude Code |
| `update-all` | อัปเดตทั้ง OpenCode และ Claude Code |
| `u-root` | ไปที่ `/root` ของ container |
| `show-aliases` | แสดง alias ทั้งหมด |

### Alias ฝั่ง Termux

| Alias | ทำอะไร |
| --- | --- |
| `u` | เข้า Ubuntu container |
| `u-root` | เข้า container แบบ login เป็น root |
| `c` | ดูไฟล์ใน home ของ Termux |
| `u-list` | ดู container ที่ติดตั้งไว้ |
| `u-install` / `u-remove` | ติดตั้ง / ลบ container |
| `openmcp-update` | อัปเดตโค้ด openmcp-ai |
| `openmcp-status` | ดู commit ล่าสุดของ repo |
| `openmcp-dir` | เข้าไปที่โฟลเดอร์ repo |

> `u-root` มีชื่อซ้ำกันสองฝั่งแต่คนละความหมาย — ฝั่ง Termux คือ login เป็น root ส่วนใน container คือไปที่ `/root`
> ฝั่ง Termux ยังมี symlink `~/u_root` ชี้ไปที่ `/root` ของ container ด้วย

คู่มือฉบับเต็ม: `cat ~/OPCODE-CHEATSHEET.txt`

---

## 🔌 MCP servers

| Server | ทำอะไร |
| --- | --- |
| `filesystem` | อ่าน/เขียนไฟล์ในโฮมไดเรกทอรี |
| `playwright` | ควบคุมเบราว์เซอร์สำหรับทดสอบเว็บ |

คำสั่งที่ config ใช้จริง:

```bash
# filesystem — เข้าถึงไฟล์ใน home
npx -y @modelcontextprotocol/server-filesystem ~

# playwright — Chromium แบบ headless
npx -y @playwright/mcp --browser chromium --headless --no-sandbox --isolated
```

ตรวจสอบสถานะ:

```bash
opencode mcp list
bash ~/.config/opencode/skills/mcp-free/scripts/check-mcp.sh ~
```

---

## ⚙️ ตัวเลือก

```bash
bash install.sh --dry-run              # แสดงแผนทั้งหมดโดยไม่แตะระบบ (ไม่ต้อง root)
bash install.sh -y                     # ตอบ yes ทุกคำถาม
bash install.sh --skip-mcp             # ข้าม MCP servers และ skills
bash install.sh --distro NAME          # ระบุ distro (ค่าเริ่มต้น ubuntu)
bash install.sh --repo-dir DIR         # ใช้ repo ที่มีอยู่ แทน ~/.openmcp
bash install.sh --uninstall            # ถอน MCP config, skills, aliases และ cheat sheet
bash install.sh --uninstall --purge    # ถอน OpenCode, Claude Code และ Bun ด้วย
```

ตัวแปรสภาพแวดล้อม:

| ตัวแปร | ผล |
| --- | --- |
| `OPENMCP_DIR` | ตำแหน่ง repo (เหมือน `--repo-dir`) |
| `OPENMCP_DISTRO` | ชื่อ distro (ค่าเริ่มต้น `ubuntu`) |
| `OPENMCP_ASSUME_YES` | ตั้งเป็น `1` เพื่อตอบ yes ทุกคำถาม (เหมือน `-y`) |
| `NO_COLOR` | ตั้งเป็น `1` เพื่อปิดสีของข้อความ |

---

## 📂 โครงสร้างโปรเจกต์

```text
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
│   ├── TROUBLESHOOTING.md     ปัญหาที่เจอบ่อยและวิธีแก้
│   └── ADAPTATION.md          สิ่งที่เปลี่ยนจากต้นฉบับ debian--ai
└── .github/workflows/ci.yml   ShellCheck + smoke + Markdown บน GitHub
```

---

## 🧪 ทดสอบ

ไม่ต้องมีมือถือก็เช็คได้ — ทุกอย่างรันใน HOME ชั่วคราว ไม่แตะระบบจริง:

```bash
bash tests/smoke.sh
```

ชุดทดสอบตรวจให้ครบทุกจุด: ทุกสคริปต์ parse ผ่าน, JSON valid, `--dry-run` ไม่เขียนอะไรลงดิสก์,
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

ตรวจ Markdown ของ README, docs และ skills:

```bash
npx -y markdownlint-cli2 "*.md" "docs/*.md" "assets/**/*.md"
```

CI รันทั้งหมดนี้ทุก push ที่ `main` และทุก pull request

> สคริปต์ทดสอบใช้ `OPENMCP_ASSUME_TERMUX=1` เพื่อรัน `install.sh` จากใน container โดยไม่แตะ proot จริง

---

## 🩺 เจอปัญหา?

- ปัญหาที่เจอบ่อยและวิธีแก้: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)
- ตรวจว่าตอนนี้อยู่ฝั่งไหน: `readlink -f /proc/self/root` — ได้ `/` คือ Termux, ได้ path ที่มี `proot-distro/containers` คือใน container
- ดู log ของ OpenCode: `tail -200 ~/.local/share/opencode/log/opencode.log`

---

## 🙏 ที่มา

โปรเจกต์นี้พัฒนาต่อยอดจาก **[Aa-ok99/debian--ai](https://github.com/Aa-ok99/debian--ai)** โดยปรับให้รองรับ Ubuntu จริง แก้ชื่อแพ็กเกจ npm ที่ล้าสมัย และเพิ่ม MCP servers กับ skills

ดูรายละเอียดการเปลี่ยนแปลงทั้งหมดได้ที่ [`docs/ADAPTATION.md`](docs/ADAPTATION.md)

---

## 📄 License

MIT — ดูที่ [LICENSE](LICENSE)

<sub>Repo by @Aa-ok99 · OpenCode is open source · Made for Termux</sub>
