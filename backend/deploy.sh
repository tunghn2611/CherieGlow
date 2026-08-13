#!/bin/bash
# ============================================================
# 🚀 Deploy Chérie Glow Backend to Railway
# ============================================================
# Usage: chmod +x deploy.sh && ./deploy.sh
# ============================================================

set -e

echo ""
echo "🌸 ═══════════════════════════════════════════════════"
echo "   Chérie Glow — Railway Deployment Script"
echo "═══════════════════════════════════════════════════"
echo ""

# ── Step 1: Check Railway CLI ─────────────────────────────
echo "📋 Bước 1: Kiểm tra Railway CLI..."
if ! command -v railway &> /dev/null; then
    echo "⚠️  Railway CLI chưa được cài đặt."
    echo "   Đang cài đặt..."
    npm install -g @railway/cli
    echo "✅ Railway CLI đã cài xong!"
else
    echo "✅ Railway CLI đã sẵn sàng: $(railway --version)"
fi

# ── Step 2: Login to Railway ──────────────────────────────
echo ""
echo "📋 Bước 2: Đăng nhập Railway..."
echo "   (Trình duyệt sẽ mở để xác thực)"
railway login
echo "✅ Đã đăng nhập Railway!"

# ── Step 3: Create or Link Project ────────────────────────
echo ""
echo "📋 Bước 3: Tạo project Railway..."
if [ -f ".railway/config.json" ]; then
    echo "✅ Project đã được liên kết"
else
    echo "   Đang tạo project mới 'cherieglow-backend'..."
    railway init
    echo "✅ Project đã được tạo!"
fi

# ── Step 4: Add MySQL ─────────────────────────────────────
echo ""
echo "📋 Bước 4: Thêm MySQL database..."
echo "   ⚠️  Hãy thêm MySQL plugin trên Railway Dashboard:"
echo "   1. Mở https://railway.app/dashboard"
echo "   2. Chọn project vừa tạo"
echo "   3. Nhấn '+ New' → 'Database' → 'MySQL'"
echo "   4. Đợi MySQL khởi tạo xong"
echo ""
read -p "   Đã thêm MySQL xong? Nhấn Enter để tiếp tục..."

# ── Step 5: Set Environment Variables ─────────────────────
echo ""
echo "📋 Bước 5: Cấu hình biến môi trường..."

# Generate JWT secrets
JWT_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)

railway variables set NODE_ENV=production
railway variables set JWT_SECRET="$JWT_SECRET"
railway variables set JWT_REFRESH_SECRET="$JWT_REFRESH_SECRET"
railway variables set JWT_EXPIRES_IN=15m
railway variables set JWT_REFRESH_EXPIRES_IN=30d

echo "✅ Biến môi trường đã được cấu hình!"
echo "   JWT_SECRET: ${JWT_SECRET:0:8}..."
echo "   JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET:0:8}..."

# ── Step 6: Deploy ────────────────────────────────────────
echo ""
echo "📋 Bước 6: Deploy backend lên Railway..."
railway up --detach
echo ""
echo "✅ Deploy thành công!"

# ── Step 7: Get Production URL ────────────────────────────
echo ""
echo "📋 Bước 7: Lấy URL production..."
echo "   Chạy lệnh sau để xem URL:"
echo "   railway domain"
echo ""
echo "   Hoặc mở Railway Dashboard để xem URL public."
echo ""

# ── Done ──────────────────────────────────────────────────
echo "🌸 ═══════════════════════════════════════════════════"
echo "   ✅ DEPLOY HOÀN TẤT!"
echo ""
echo "   📌 Việc cần làm tiếp:"
echo "   1. Chạy 'railway domain' để lấy URL"  
echo "   2. Mở URL/api/health để kiểm tra"
echo "   3. Cập nhật URL vào app iOS (APIService.swift)"
echo "   4. Build & cài app lên iPhone qua Xcode"
echo "═══════════════════════════════════════════════════"
echo ""
