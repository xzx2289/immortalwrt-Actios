@echo off
@title 一键刷入openwrt 补丁
color 1f

mode con cols=100 lines=30

@echo adb重启至fastboot模式中(如果在fastboot模式了下面出现error: no devices/emulators found不用管)
adb reboot bootloader
set /p a=确定执行吗？ （1继续，0退出）
if /i '%p%'=='1' goto continue
if /i '%a%'=='0' goto end
timeout /NOBREAK 3
fastboot erase boot
fastboot flash boot boot.img
timeout /NOBREAK 3
fastboot erase rootfs
fastboot -S 200m flash rootfs system.img

pause
@echo 刷机完成重启...
timeout 5
fastboot reboot