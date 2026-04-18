# NOTICE.md

`apple-helper` is MIT-licensed. It was built with reference to the following third-party Open Source projects. License texts are reproduced in full for attribution.

---

## iMCP (MIT)

Source: https://github.com/mattt/iMCP
Audited SHA: `6d0df253cd31d485edaede4929dc3e92d5825cab` (2026-01-30)

Our EventKit and Contacts implementations in `Sources/AppleHelper/` draw on patterns we learned reading iMCP's `App/Services/{Calendar,Reminders,Contacts}.swift` files, its `App/Extensions/EventKit+Extensions.swift`, and related types. No files are copied byte-for-byte; implementations target a different CLI shape and cover ops iMCP does not expose. iMCP is credited here because the reference meaningfully shaped our code.

iMCP's license in full:

```
MIT License

Copyright (c) 2025 Mattt (https://mat.tt)

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```
