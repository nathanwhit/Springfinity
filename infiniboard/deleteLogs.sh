#!/usr/local/bin/zsh
remote_log_dir='/var/mobile/Documents/InspectiveC/SpringBoard'
local_log_dir='./logs'
ssh '-T' '-p' "${THEOS_DEVICE_PORT}" "root@${THEOS_DEVICE_IP}" << EOF
    find "${remote_log_dir}" -name '*.log' -delete
    exit
EOF

find "${local_log_dir}" -name '*.log' -delete
echo "All logs deleted"