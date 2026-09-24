# 🚀 GitHub Upload Guide — Scan Me! v1.0.0

> 🧑‍💻 **For the project owner with ZERO coding knowledge**  
> This guide uses normal website buttons and does not require command-line coding.

---

## 🎯 What You Will Do

At the end, you will have:

- 🌐 A GitHub repository for **Scan Me!**
- 📁 The project files uploaded and visible on GitHub
- 🏷️ A release named **`v1.0.0`**
- 📦 A downloadable **`ScanMe.exe` binary asset**
- 🧪 A release page that visitors can find and use

> 💡 **Important:** `ScanMe.exe` is a launcher. It needs the project folders beside it—especially `src`, `assets`, and `config`. For the easiest download for users, also upload a ZIP containing the complete project.

## 🧰 Before You Start

You need only:

- 🖥️ A Windows computer
- 🌐 An internet connection
- 👤 A free GitHub account
- 📂 The completed `Scan Me!` project folder
- 🧭 About 10–15 minutes

No programming knowledge is required. 😊

---

## 1️⃣ Create a New Repository on GitHub.com

### 🔹 Open the create-repository page

1. 🌐 Open [github.com](https://github.com/) in your browser.
2. 👤 Sign in to GitHub. If you do not have an account, click **Sign up** and create one.
3. ➕ Click the **+** symbol in the upper-right corner.
4. 🆕 Click **New repository**.

### 🔹 Fill in the simple details

On the repository page:

1. 📝 Under **Repository name**, type a name such as `Scan-Me` or `ScanMe`.
   - Do not use spaces. Hyphens are okay.
2. 📄 Under **Description**, type: `A fast Windows file scanner, catalog, and interactive root tree tool.`
3. 🔒 Choose **Public** if you want anyone to view and download the project. Choose **Private** if only you and invited people should see it.
4. ⚠️ For a web upload, leave these boxes unchecked:
   - **Add a README file**
   - **Add .gitignore**
   - **Choose a license**
5. 🚀 Click **Create repository**.

> 💡 We will upload your existing `README.md` in the next step, so leaving the automatic README unchecked prevents a duplicate-file conflict.

---

## 2️⃣ Upload the Project Files

### ⭐ Recommended: Direct Web Upload

This is the simplest option for a first upload.

1. 📂 Open your completed project folder in File Explorer.
2. 👁️ Press **Ctrl + H** to show hidden files and folders. This helps include files such as `.vscode`, `.clinerules`, and `.cursorrules`.
3. 🌐 Go back to your new GitHub repository tab.
4. ➕ Click **Add file**.
5. 📤 Click **Upload files**.
6. 🖱️ Drag the **contents of the project folder** into the GitHub upload box.
   - Drag the items such as `src`, `assets`, `config`, `docs`, `tools`, `tests`, `README.md`, `ScanMe.exe`, and other project files.
   - Do not drag only the outer folder if you want these items at the repository top level.
7. ⏳ Wait until the upload bar finishes and the files appear in the list.
8. 📝 Scroll down to **Commit changes**.
9. ✍️ Type a short message such as `Initial Scan Me v1.0.0 upload`.
10. ✅ Click **Commit changes**.

### 🗂️ What should be uploaded?

Upload the project files needed to run and understand the application:

- `src`
- `assets`
- `config`
- `docs`
- `tools`
- `tests`
- `README.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `ScanMe.exe`
- `run.bat`

The `output` folder contains generated scan results. You can skip it for a clean public repository; users can create new results when they run the app.

### 🛠️ Alternative: GitHub Desktop

If the web page will not upload a large folder, use GitHub Desktop:

1. 🌐 Download and install [GitHub Desktop](https://desktop.github.com/).
2. 👤 Open it and sign in to GitHub.
3. 🆕 Choose **File → New repository**.
4. 📝 Name it `Scan-Me`.
5. 📂 Choose an empty local location for the new repository.
6. ✅ Create the repository with a README.
7. 📂 Copy all of the original `Scan Me!` project files into the new repository folder.
   - Press **Ctrl + H** first if you want hidden project files included.
8. 🔄 Return to GitHub Desktop and choose **File → Add local repository**.
9. 📂 Select the new repository folder.
10. 👀 Review the files shown in the changes list.
11. ✍️ Type `Initial Scan Me v1.0.0 upload` in the description box.
12. ✅ Click **Commit to main**.
13. 🚀 Click **Publish repository**.

> 💡 This alternative uses GitHub Desktop buttons only. It does not require you to type Git commands.

---

## 3️⃣ Create the `v1.0.0` Release

1. 🌐 Return to your repository page on GitHub.
2. 👉 In the right sidebar, find **Releases**.
3. 🆕 Click **Draft a new release**.
4. 🏷️ Click **Choose a tag** and type:

   ```text
   v1.0.0
   ```

   If GitHub asks you to create the tag, choose the `main` branch and create it.
5. 📝 Under **Release title**, type:

   ```text
   Scan Me! v1.0.0 — Windows File Intelligence & Interactive Root Tree
   ```

6. 📋 Open the local file `docs/RELEASE_NOTES_v1.0.0.md`, copy the text, and paste it into the release description box.
7. 📎 Scroll to **Attach files by dragging & dropping**.
8. 📤 Drag in the local file named `ScanMe.exe`.
9. ⏳ Wait until `ScanMe.exe` appears in the asset list.
10. 📦 **Recommended:** also create a ZIP of the complete project and attach it:
    - Right-click the project folder.
    - Choose **Send to → Compressed (zipped) folder**.
    - Attach the resulting ZIP to the release.
11. 🚀 Click **Publish release**.

> 📦 The separate `ScanMe.exe` is the requested binary asset. The complete ZIP is the friendliest download because the EXE must run with the project folders beside it.

---

## 4️⃣ Check Your Release

After publishing:

1. 🎉 GitHub should show a page headed **Scan Me! v1.0.0**.
2. 🔎 Confirm the tag says **`v1.0.0`**.
3. 📎 Confirm the **Assets** section contains `ScanMe.exe`.
4. 📦 Confirm the complete project ZIP is also listed, if you added it.
5. 📥 Click each asset once to make sure the download starts.
6. 🔗 Copy the repository URL from the browser address bar. This is the link you can share.

---

## 📤 What Users Should Download?

For the smoothest experience, ask users to download the **complete project ZIP**:

1. Open the GitHub Release page.
2. Download the complete ZIP asset.
3. Right-click the ZIP and choose **Extract All**.
4. Open the extracted `Scan Me!` folder.
5. Double-click `ScanMe.exe`.

They can also download `ScanMe.exe` separately, but it must remain beside the project folders. A copy of the EXE by itself will show a startup error.

For the optional HTML right-click actions, the user runs `tools\register_protocol.ps1` once from the project folder.

---

## 🆘 Simple Troubleshooting

### 🟥 GitHub says the README already exists

Return to **Add file → Upload files** and upload the project contents. If the repository was created with an automatic README, open the existing `README.md`, replace its contents with your project README, and commit the change before publishing the release.

### 🟥 Some dotfiles are missing

In File Explorer, press **Ctrl + H** to show hidden files, then upload again or use GitHub Desktop.

### 🟥 The upload is too large or stops

Use the GitHub Desktop alternative above. It is designed for projects with many files.

### 🟥 `ScanMe.exe` is not listed under Assets

Return to **Draft a new release**, open the **Assets** area, drag in `ScanMe.exe`, wait for the upload to finish, and publish the release. Do not close the page while the file is still uploading.

### 🟥 A user gets a startup error after downloading only the EXE

Tell the user to download the complete ZIP or keep `src`, `assets`, and `config` beside `ScanMe.exe`. The EXE is a launcher and relies on the PowerShell/WPF project files.

### 🟥 The old Windows icon is displayed

This is Windows Icon Cache. Run:

```powershell
ie4uinit.exe -show
```

Then restart Windows Explorer if needed. The application itself is not damaged.

---

## ✅ Final Checklist

- [ ] 🌍 GitHub repository created
- [ ] 📁 Project files uploaded
- [ ] 📖 Project `README.md` visible on the repository home page
- [ ] 🏷️ Tag `v1.0.0` created
- [ ] 🚀 Release published
- [ ] 📎 `ScanMe.exe` attached as a binary asset
- [ ] 📦 Complete project ZIP attached for non-technical users
- [ ] 🔗 Release URL copied and saved for sharing

**You are ready to publish Scan Me! v1.0.0.** 🎉🚀

