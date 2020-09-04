#! /usr/bin/env dcli

import 'dart:io';
import 'package:dcli/dcli.dart';
import 'package:meta/meta.dart';

class InstallationPreparation {
  ///
  static void cloneOSXKVM() {
    if (exists('$HOME/OSX-KVM')) {
      var allowed = ask(
          'Path $HOME/OSX-KVM found, re-clone to ensure latest version?'
          ' \n [y(Y)/n(N)]',
          defaultValue: 'n',
          validator: Ask.alpha);
      if (allowed.toLowerCase() == 'y') {
        'rm -rf OSX-KVM'.start(privileged: true, workingDirectory: '$HOME');
        try {
          'git clone https://github.com/kholia/OSX-KVM.git'
              .start(privileged: true, workingDirectory: '$HOME');
        } on Exception catch (_) {
          rethrow;
        }
      } else {
        echo('Continuing with local version');
      }
    }
  }

  ///
  static void fetchInstaller() {
    try {
      './fetch-macOS.py'.start(
          privileged: true, workingDirectory: '$HOME/OSX-KVM', terminal: true);
    } on Exception catch (_) {
      rethrow;
    }
  }

  ///
  static void convertToIMG() {
    try {
      'dmg2img BaseSystem.dmg BaseSystem.img'
          .start(privileged: true, workingDirectory: '$HOME/OSX-KVM');
    } on Exception catch (_) {
      rethrow;
    }
  }

  ///
  static void createHDD({@required int sizeGB}) {
    try {
      'qemu-img create -f qcow2 mac_hdd_ng.img ${sizeGB.toString()}G'
          .start(privileged: true, workingDirectory: '$HOME/OSX-KVM');
    } on Exception catch (_) {
      rethrow;
    }
  }

  ///
  static void setupQuickNetworking() {
    var attempts;
    try {
      'ip tuntap add dev tap0 mode tap'
          .start(privileged: true, workingDirectory: '$HOME/OSX-KVM');
      'ip link set tap0 up promisc on'
          .start(privileged: true, workingDirectory: '$HOME/OSX-KVM');
      'ip link set dev virbr0 up'
          .start(privileged: true, workingDirectory: '$HOME/OSX-KVM');
      'ip link set dev tap0 master virbr0'
          .start(privileged: true, workingDirectory: '$HOME/OSX-KVM');
    } on Exception catch (_) {
      echo('tap0 unavailable freeing resource and retrying ${attempts}');
      attempts++;
      'ip link delete tap0'.start(privileged: true);
      if (attempts <= 3) {
        setupQuickNetworking();
      } else {
        echo(
            'unable to setup networking after 3 retries. There might be some issue other than unavailable resources');
        exit(1);
      }
    }
  }

  ///
  static void libVirtManager() {
    r'sed -i "s/CHANGEME/$USER/g" macOS-libvirt-Catalina.xml'
        .start(privileged: true, workingDirectory: '$HOME/OSX-KVM');
    'virt-xml-validate macOS-libvirt-Catalina.xml'
        .start(workingDirectory: '$HOME/OSX-KVM');
    'virsh --connect qemu:///system define macOS-libvirt-Catalina.xml'
        .start(workingDirectory: '$HOME/OSX-KVM');
  }
}

///
bool checkSize(String size) {
  if (int.tryParse(size) < 30) {
    echo('Size must be at least 30GB');
    return false;
  }
  return true;
}