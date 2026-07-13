# Stage 1: Cài đặt dependencies (tận dụng cache tốt hơn)
FROM docker.io/node:24-alpine AS deps
WORKDIR /app

# Copy riêng các file quản lý package để cài đặt trước
COPY package.json package-lock.json* ./

# Cài đặt production dependencies (không devDependencies)
# --omit=dev thay cho --only=production (npm 11 không hỗ trợ cờ cũ)
RUN npm ci --omit=dev --ignore-scripts

# Stage 2: Production image (tinh gọn)
FROM docker.io/node:24-alpine AS production
WORKDIR /app

ENV NODE_ENV=production

# Kiểm tra phiên bản Node (đảm bảo >= 24)
RUN node -e "const v=parseInt(process.versions.node.split('.')[0],10); if(v<24){console.error('ERROR: Node >= 24 required, got '+v);process.exit(1);}"

# Cài timezone data nếu cần
RUN apk add --no-cache tzdata

# Tạo user không root để chạy ứng dụng
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Copy node_modules từ stage deps, gán quyền sở hữu ngay khi copy
# (tránh chown -R riêng biệt làm phình layer và chậm build)
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules

# Copy toàn bộ source code (đã được lọc qua .dockerignore), gán quyền luôn
COPY --chown=appuser:appgroup . .

# Đảm bảo entrypoint có quyền thực thi — chạy trước khi chuyển user
# vì appuser có thể không có quyền chmod trên file thuộc sở hữu của chính mình
# tùy vào cách file được copy, nên thực hiện khi vẫn còn quyền root
RUN if [ -f /app/docker-entrypoint.sh ]; then chmod +x /app/docker-entrypoint.sh; fi

# Chuyển sang user không root
USER appuser

# Expose port nếu ứng dụng có listen (tùy chọn)
# EXPOSE 3000

# Healthcheck cơ bản — điều chỉnh lệnh theo cách app thực sự báo hiệu "còn sống"
# HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
#   CMD node -e "process.exit(0)"

ENTRYPOINT ["/app/docker-entrypoint.sh"]
