{ den, lib, ... }:
let
  # OrbStack keeps its containers and machines on a dedicated APFS volume, added
  # to this APFS container (disk3 is the Mac's internal one, which also holds
  # Macintosh HD and the Nix Store).
  container = "disk3";
  volumeName = "Container Data";
  mountPoint = "/Volumes/${volumeName}";

  # Each user gets their own OrbStack data directory on the volume, since
  # OrbStack's data (like its ~/.orbstack config) is per user.
  dataDir = userName: "${mountPoint}/OrbStack/${userName}";

  # Run as root, at activation and at boot: makes sure the volume exists, is
  # encrypted, is unlocked and is mounted at $mountPoint. Safe to run repeatedly;
  # exits non-zero (with a message) if the volume can't be used.
  #
  # Encryption works like the Nix installer's for the Nix Store volume: a random
  # passphrase, stored in the System keychain under the volume's UUID, unlocks
  # the volume with the "disk" crypto user. The keychain item also lets macOS's
  # APFSUserAgent and CSUserAgent unlock it.
  mkVolumeSetup =
    pkgs:
    pkgs.writeShellApplication {
      name = "container-data-volume";
      runtimeInputs = [ pkgs.jq ];
      text = ''
        container=${lib.escapeShellArg container}
        name=${lib.escapeShellArg volumeName}
        mountPoint=${lib.escapeShellArg mountPoint}
        keychain=/Library/Keychains/System.keychain

        # The device identifier (e.g. disk3s8) of the volume named $name in
        # $container, or nothing if there is none. Fails if $container isn't an
        # APFS container.
        volumeDevice() {
          /usr/sbin/diskutil apfs list -plist "$container" \
            | /usr/bin/plutil -convert json -o - - \
            | jq -r --arg name "$name" \
              '.Containers[].Volumes[] | select(.Name == $name) | .DeviceIdentifier'
        }

        # A key from `diskutil info` for the volume, or nothing if it isn't set
        info() {
          /usr/sbin/diskutil info -plist "$device" \
            | /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null || true
        }

        # The volume's passphrase from the System keychain; fails if there is none
        storedPassphrase() {
          /usr/bin/security find-generic-password -s "$uuid" -w "$keychain" 2>/dev/null
        }

        if ! device=$(volumeDevice); then
          echo "$container is not an APFS container" >&2
          exit 1
        fi

        # Created unencrypted, then encrypted below once its passphrase is safely
        # in the keychain (the passphrase is keyed by the UUID, which only exists
        # once the volume does).
        if [[ -z $device ]]; then
          echo "creating the APFS volume '$name' in $container..." >&2
          /usr/sbin/diskutil apfs addVolume "$container" APFS "$name" >&2
          device=$(volumeDevice)
        fi
        uuid=$(info VolumeUUID)

        # Unlocking also mounts it
        if [[ $(info Locked) == true ]]; then
          if ! passphrase=$(storedPassphrase); then
            echo "'$name' is locked and $keychain has no passphrase for it ($uuid)" >&2
            exit 1
          fi
          /usr/sbin/diskutil apfs unlockVolume "$device" -stdinpassphrase <<<"$passphrase" >&2
        fi
        if [[ -z $(info MountPoint) ]]; then
          /usr/sbin/diskutil mount "$device" >&2
        fi
        if [[ $(info MountPoint) != "$mountPoint" ]]; then
          echo "'$name' ($device) is mounted at '$(info MountPoint)', not '$mountPoint'" >&2
          exit 1
        fi

        # Encrypting needs the volume mounted, hence after the above
        if [[ $(info FileVault) != true ]]; then
          # Store the passphrase first and read it back, so the volume never ends
          # up encrypted with a passphrase that isn't in the keychain. A passphrase
          # left over from an earlier failed attempt is reused. The command goes to
          # `security` on stdin (interactive mode), so the passphrase isn't on a
          # command line; interactive mode always exits 0, hence the read-back.
          if ! passphrase=$(storedPassphrase); then
            passphrase=$(/usr/bin/openssl rand -base64 32)
            addPassphrase=(
              add-generic-password
              -a "$name"
              -s "$uuid"
              -l "$name encryption password"
              -D "Encrypted volume password"
              -j "Added by magnanix (den.aspects.orbstack) to unlock the volume"
              -T /System/Library/CoreServices/APFSUserAgent
              -T /System/Library/CoreServices/CSUserAgent
              -T /usr/bin/security
              -w "$passphrase"
              "$keychain"
            )
            { printf '"%s" ' "''${addPassphrase[@]}"; echo; } | /usr/bin/security -q -i
            if [[ $(storedPassphrase) != "$passphrase" ]]; then
              echo "could not store the passphrase for '$name' in $keychain" >&2
              exit 1
            fi
          fi
          echo "encrypting the APFS volume '$name' ($device)..." >&2
          /usr/sbin/diskutil apfs encryptVolume "$device" -user disk -stdinpassphrase \
            <<<"$passphrase" >&2
        fi

        # Honour file ownership on the volume, so each user's data directory
        # stays private to them.
        if [[ $(info GlobalPermissionsEnabled) != true ]]; then
          /usr/sbin/diskutil enableOwnership "$mountPoint" >&2
        fi
      '';
    };
in
{
  # OrbStack: Docker containers and Linux machines on macOS. The nixpkgs package
  # is darwin-only (an Apple silicon build) and unfree, so only the `darwin`
  # class installs anything.
  den.aspects.orbstack = {
    includes = [
      (den.batteries.unfree [
        "orbstack"
      ])

      # Per user: the user's data directory on the volume, and OrbStack's data
      # location setting pointing at it.
      (
        { user, ... }:
        {
          # Runs after the volume setup in extraActivation. If the volume isn't
          # mounted, that step has already warned.
          darwin.system.activationScripts.postActivation.text = ''
            if /sbin/mount | grep -qF ${lib.escapeShellArg " on ${mountPoint} ("}; then
              install -d -o ${user.userName} -g staff -m 700 ${lib.escapeShellArg (dataDir user.userName)}
            fi
          '';

          # OrbStack has no `orb config` key for the data location; the app's
          # Settings > Storage > Data location writes `data_dir` to
          # ~/.orbstack/vmconfig.json, so set that key and keep the rest of the
          # file. Takes effect the next time OrbStack starts. Existing data is not
          # moved to the new location.
          homeManager =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            let
              jq = lib.getExe pkgs.jq;
              orbstackDir = "${config.home.homeDirectory}/.orbstack";
              vmconfig = "${orbstackDir}/vmconfig.json";
              target = dataDir user.userName;
            in
            {
              home.activation.orbstackDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                orbstackVmconfig=${lib.escapeShellArg vmconfig}
                orbstackDataDir=${lib.escapeShellArg target}
                if [[ ! -f $orbstackVmconfig ]] \
                  || [[ $(${jq} -r '.data_dir // ""' "$orbstackVmconfig") != "$orbstackDataDir" ]]; then
                  if [[ -d ${lib.escapeShellArg orbstackDir}/data ]]; then
                    warnEcho "OrbStack data in ~/.orbstack/data is not moved to $orbstackDataDir"
                  fi
                  if [[ -v DRY_RUN ]]; then
                    echo "Would set OrbStack's data_dir to $orbstackDataDir in $orbstackVmconfig"
                  else
                    mkdir -p -m 700 ${lib.escapeShellArg orbstackDir}
                    orbstackTmp=$(mktemp "$orbstackVmconfig.XXXXXX")
                    { cat "$orbstackVmconfig" 2>/dev/null || echo '{}'; } \
                      | ${jq} --arg dir "$orbstackDataDir" '.data_dir = $dir' >"$orbstackTmp"
                    mv "$orbstackTmp" "$orbstackVmconfig"
                  fi
                fi
              '';
            };
        }
      )
    ];

    darwin =
      { pkgs, ... }:
      let
        volumeSetup = lib.getExe (mkVolumeSetup pkgs);
      in
      {
        environment.systemPackages = [ pkgs.orbstack ];

        # Set up the volume early in activation (before postActivation, which
        # creates the users' directories on it). A volume problem shouldn't abort
        # the whole switch, so it's reported as a warning instead.
        system.activationScripts.extraActivation.text = ''
          if ! ${volumeSetup}; then
            echo "warning: the '${volumeName}' volume for OrbStack could not be set up" >&2
          fi
        '';

        # An encrypted volume stays locked after a reboot until something unlocks
        # it, so unlock and mount it at boot (nix-darwin waits for /nix/store).
        launchd.daemons.container-data-volume = {
          command = volumeSetup;
          serviceConfig = {
            RunAtLoad = true;
            StandardOutPath = "/var/log/container-data-volume.log";
            StandardErrorPath = "/var/log/container-data-volume.log";
          };
        };
      };
  };
}
