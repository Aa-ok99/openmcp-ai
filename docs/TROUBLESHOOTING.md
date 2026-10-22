# 🛠 Troubleshooting

## `Error: attempted to run proot-distro in a proot session`

**สาเหตุ** — คุณสั่ง `proot-distro` จากภายใน container อยู่แล้ว `proot-distro` ใช้ proot ซ้อนกันไม่ได้

**แก้** — ถ้าอยู่ใน container ให้รันสคริปต์ชั้นในโดยตรง:

```bash
bash ~/.openmcp/scripts/ubuntu-setup.sh
```

ถ้าอยู่ฝั่ง Termux ให้รัน `bash install.sh` (ไม่ใช่ `ubuntu-setup.sh`)

**ตรวจว่าอยู่ฝั่งไหน**:

```bash
[ -f /.dockerenv ] && echo container || echo termux
cat /etc/os-release | grep ^ID=
```

---

## `Chromium distribution 'chrome' is not found at /opt/google/chrome/chrome`

**สาเหตุ** — `@playwright/mcp` ค่า default เป็น Chrome channel ซึ่งไม่ได้ติดตั้งไว้

**แก้** — ต้องมี `--browser chromium` ใน command ของ MCP server:

```json
"command": ["npx", "-y", "@playwright/mcp", "--browser", "chromium",
            "--headless", "--no-sandbox", "--isolated"]
```

---

## `error while loading shared libraries: libnspr4.so`

**สาเหตุ** — ติดตั้งเบราว์เซอร์แล้วแต่ขาด shared libraries ของระบบ

**แก้** — ต้องใช้ `playwright-core` ตัวเดียวกับที่ MCP server ใช้:

```bash
node ~/.npm/_npx/<hash>/node_modules/playwright-core/cli.js install-deps chromium
```

หา `<hash>` ด้วย:

```bash
find ~/.npm/_npx -maxdepth 5 -path '*/node_modules/playwright-core/cli.js'
```

> ถ้ามีหลายตัว ให้เลือกตัวที่อยู่คู่กับ `node_modules/@playwright/mcp` เพราะแต่ละเวอร์ชันใช้ chromium revision ต่างกัน

---

## MCP server ค้างที่ `pending`

**สาเหตุ** — npx ต้อง resolve package ครั้งแรกแล้วช้ากว่า startup timeout

**แก้**

```bash
npx -y @playwright/mcp --help   # อุ่นแคชให้เร็วขึ้น
```

และเพิ่ม timeout ใน `~/.config/opencode/opencode.json`:

```json
"mcp": { "timeout": { "startup": 120000 } }
```

---

## MCP server ไม่โผล่ใน `opencode mcp list` เลย

**สาเหตุ** — server ไม่มี field `type` หรือ `type` ผิด → OpenCode **ละเลยเงียบ ๆ** ไม่มี warning

**แก้** — ต้องมี `"type": "local"` หรือ `"type": "remote"` เสมอ

```bash
bash ~/.config/opencode/skills/mcp-free/scripts/check-mcp.sh ~   # จับเคสนี้ได้
```

---

## `opencode mcp list` แสดง `No MCP servers configured`

**สาเหตุ** — สองเรื่องที่เป็นไปได้

1. รันจาก directory ที่ไม่ใช่ที่ session ใช้ — project config ถูก scope ตาม directory
2. เพิ่งสร้าง project config ใหม่ — config watcher ยังไม่ได้ register

**แก้** — รอสองสามวินาทีแล้วลองใหม่ หรือ cd ไปที่ working directory ของ session

---

## Bun ติดตั้งไม่ได้

**สาเหตุ** — Bun ใช้ syscall ที่ proot รองรับไม่ครบ

**แก้** — ไม่เป็นไร สคริปต์จะข้ามให้เองแล้วแจ้ง warning OpenCode ใช้ Node.js เป็นพื้นฐาน ไม่ต้องมี Bun

---

## `npm install -g` แล้วยังเรียก `opencode` ไม่ได้

**สาเหตุ** — npm global prefix ไม่ได้อยู่ใน PATH

**ตรวจสอบ**

```bash
npm config get prefix
echo $PATH
```

**แก้**

```bash
npm config set prefix /usr/local
export PATH="/usr/local/bin:$PATH"
```

---

## alias ไม่ทำงาน

**สาเหตุ** — `.bashrc` ยังไม่ถูกโหลด

**แก้**

```bash
source ~/.bashrc
show-aliases
```

ถ้า `source ~/.bashrc` ไม่มีผล ให้ตรวจว่า `.bashrc` มีบรรทัด

```bash
source ~/.opencode_aliases
```

---

## อยากรู้ว่า container อยู่ตรงไหน

```bash
proot-distro list
ls /data/data/com.termux/files/usr/var/lib/proot-distro/containers/
```

จากฝั่ง Termux ใช้ `u_root` ที่ `install.sh` สร้างไว้ หรือ:

```bash
ls -la ~/u_root
```

---

## ดู log

```bash
tail -200 ~/.local/share/opencode/log/opencode.log
grep -iE "mcp|playwright" ~/.local/share/opencode/log/opencode.log | tail -20
```

> ปิดบัง API key และ authorization header ก่อนแชร์ log
