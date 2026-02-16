# Unity vs Flutter: Spine Animation Runtime Differences

## Tóm tắt vấn đề

> **Unity "che lỗi" cho bạn, Flutter thì không.**

## So sánh chi tiết

| Vấn đề              | Unity      | Flutter |
| ------------------- | ---------- | ------- |
| Reset bone          | ✔ Tự động  | ❌ Không |
| Clear attachment    | ✔          | ❌       |
| Fix loop            | ✔          | ❌       |
| Che lỗi animation   | ✔          | ❌       |
| Đọc JSON đúng spec  | ❌ (có sửa) | ✔       |
| Đòi animation chuẩn | ❌          | ✔       |

## Giải pháp cho Flutter

### 1. Script `fix_spine_json.dart`

Script này tự động fix các vấn đề mà Unity tự động xử lý:

- ✅ Translate timelines ending without explicit (0,0)
- ✅ Rotate timelines ending without explicit angle
- ✅ Scale timelines ending without explicit values
- ✅ Missing bone timelines (Unity auto-resets, Flutter doesn't)
- ✅ Skill bones with extreme setup poses (Unity clamps, Flutter doesn't)
- ✅ Attachment offsets in skins (Unity normalizes, Flutter doesn't)

**Chạy script:**
```bash
dart fix_spine_json.dart
```

### 2. Best Practices

1. **Luôn chạy `fix_spine_json.dart` trước khi dùng animation**
2. **Kiểm tra animation trong Spine Editor**, không chỉ Unity
3. **Đảm bảo frame đầu = frame cuối** cho seamless loop
4. **Reset bone state** khi đổi animation (nếu cần)

### 3. Checklist Animation

- [ ] Frame đầu có `time: 0` explicit
- [ ] Frame cuối = frame đầu (cho loop)
- [ ] Tất cả bones có timeline (hoặc dùng setup pose)
- [ ] Translate không có giá trị extreme (> 100)
- [ ] Attachment offsets trong skin < 100
- [ ] Animation duration được tính đúng

## Kết luận

> **Unity làm bạn tưởng animation đúng.  
> Flutter cho bạn biết animation có đúng hay không.**

Flutter bắt bạn làm **đúng ngay từ đầu**, nhưng animation chuẩn sẽ chạy mọi engine.

