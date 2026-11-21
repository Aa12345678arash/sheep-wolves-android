# گرگ و میش — سرویس اتاق آنلاین

این پوشه پیاده‌سازی آزمایشی سرویس اتاق خصوصی است؛ هنوز به نسخه اندروید متصل یا روی اینترنت منتشر نشده است.

نشانی سرویس در تنظیم پروژه Godot با کلید `application/config/wolf_dusk_online_service_url` نگهداری می‌شود. تا زمان استقرار Worker این مقدار خالی می‌ماند و دکمه آنلاین در بازی غیرفعال است. پس از دریافت زیردامنه واقعی `workers.dev`، مقدار آن به `https://نام-سرویس.زیردامنه-حساب.workers.dev` تغییر می‌کند و APK جدید باید ساخته و روی دستگاه آزمایش شود.

## ساختار
- `src/engine.ts`: موتور مستقل و قطعی قواعد و وضعیت صفحه
- `src/index.ts`: Worker HTTP، اتاق Durable Object، WebSocket، احراز هویت بازیکن و بازیابی اتصال
- `wrangler.jsonc`: اتصال SQLite-backed Durable Object و دامنه workers.dev
- `tests/engine.test.ts`: آزمون‌های توپولوژی، چیدمان مهره‌ها، حرکت، گرفتن و پایان مهلت زنجیره
- `tests/room-security.test.ts`: آزمون عدم ارسال broadcast به سوکت‌های احرازنشده و سریالی‌بودن عملیات Durable Object

## API اولیه
- `GET /health`
- `POST /api/rooms` با `displayName`، `protocolVersion` و `rulesetId`
- `POST /api/rooms/{roomCode}/join` با همان نسخه پروتکل/قواعد و نام بازیکن
- `GET /api/rooms/{roomCode}/ws` برای ارتقای اتصال به WebSocket؛ توکن در query string یا URL قرار نمی‌گیرد.
- `GET /join/{roomCode}` صفحه وب ساده کد دعوت

توکن بازیکن فقط یک بار به کلاینت برگردانده و در Durable Object به شکل SHA-256 ذخیره می‌شود. کد اتاق ۹۶ بیت تصادفی و توکن بازیکن ۲۵۶ بیت تصادفی است. توکن در نخستین پیام WebSocket روی اتصال TLS ارسال می‌شود، نه در نشانی URL؛ لینک دعوت فقط کد اتاق را حمل می‌کند. تغییرات اتاق، اتصال هم‌زمان و حرکت‌ها در صف سریالی Durable Object پردازش می‌شوند تا دو درخواست هم‌زمان وضعیت یکسان را به‌طور متناقض تغییر ندهند.

## اجرای محلی
در این پوشه:
```sh
npm install
npm run typecheck
npm test
npx wrangler dev
```

## استقرار رایگان پس از تأیید آزمون‌ها
دامنه اختصاصی لازم نیست. حساب رایگان Cloudflare یک زیردامنه `workers.dev` می‌دهد. برای اتصال مخزن:
1. در Cloudflare یک حساب بسازید و وارد Dashboard شوید.
2. Workers & Pages → Create application → Connect to Git را انتخاب کنید.
3. مخزن `Aa12345678arash/sheep-wolves-android` را متصل کنید.
4. شاخه `WOLF-DUSK-ONLINE-001-INVITE-ROOMS` و مسیر ریشه `rebuild/WOLF-DUSK-007/online/worker` را انتخاب کنید؛ نام Worker را دقیقاً `wolf-dusk-rooms` بگذارید تا با `wrangler.jsonc` یکسان باشد.
5. Build command را `npm install && npm run typecheck && npm test` و Deploy command را `npx wrangler deploy` بگذارید.
6. پس از استقرار، آدرس `workers.dev` ساخته‌شده را ثبت کنید؛ لینک دعوت از مسیر `/join/{roomCode}` ساخته خواهد شد.

این پروژه از Durable Object با SQLite استفاده می‌کند؛ در طرح رایگان، محدودیت‌های روزانه اعمال می‌شود و در صورت عبور از آن‌ها درخواست‌های جدید ممکن است رد شوند. هزینه یا ارتقای پولی بدون تأیید مالک انجام نمی‌شود.

## دروازه‌های انتشار
تا زمانی که همه موارد زیر انجام نشده‌اند، نباید به بازیکنان لینک عمومی داده شود:
- CI سبز و آزمون‌های سوءاستفاده/هم‌زمانی/اتصال مجدد کامل؛
- تطبیق قطعی اختلاف مستندشده در تعداد گرفتن‌های زنجیره‌ای با قواعد پذیرفته‌شده بازی؛
- ادغام کلاینت Godot (ساخت/پیوستن اتاق، WebSocket امن، پیام آماده‌بودن، بازنمایی snapshot معتبر، ارسال حرکت و بازیابی sequence پس از reconnect)؛
- استقرار توسط مالک و آزمون دو دستگاه اندرویدی روی اینترنت واقعی.

نسخه پایدار ۰۴۴ و شاخه `main` خارج از این کار باقی می‌مانند.
