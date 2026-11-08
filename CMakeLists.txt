cmake_minimum_required(VERSION 3.16)

project(plasma-serverstatus)

find_package(ECM 5.240.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${ECM_KDE_MODULE_DIR})

include(KDEInstallDirs)

find_package(KF6Plasma REQUIRED)

plasma_install_package(package org.kde.plasma.serverstatus)

install(FILES package/contents/notifications/org.kde.plasma.serverstatus.notifyrc DESTINATION ${KDE_INSTALL_KNOTIFYRCDIR})
install(FILES package/contents/notifications/org.kde.plasma.serverstatus.desktop DESTINATION ${KDE_INSTALL_APPDIR})
