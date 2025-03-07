# Test that checks whether the correct hooks are created in the hooks folder.
{ git, perl, coreutils, runCommand, run, lib, mktemp }:
let
  tests = {
    basic-test = {
      expectedHooks = [ "pre-commit" ];
      conf.hooks.shellcheck.enable = true;
    };

    multiple-hooks-test = {
      expectedHooks = [ "commit-msg" "pre-commit" ];
      conf.hooks = {
        shellcheck.enable = true;
        nixpkgs-fmt = {
          enable = true;
          stages = [ "commit-msg" ];
        };
      };
    };

    non-default-stage-test = {
      expectedHooks = [ "commit-msg" ];
      conf.hooks.nixpkgs-fmt = {
        enable = true;
        stages = [ "commit-msg" ];
      };
    };

    default-stage-test = {
      expectedHooks = [ "commit-msg" ];
      conf = {
        default_stages = [ "commit-msg" ];
        hooks.nixpkgs-fmt.enable = true;
      };
    };

    manual-default-stage-test = {
      expectedHooks = [ ];
      conf = {
        default_stages = [ "manual" ];
        hooks.nixpkgs-fmt.enable = true;
      };
    };

    multiple-default-stages-test = {
      expectedHooks = [ "pre-push" ];
      conf = {
        default_stages = [ "manual" "pre-push" ];
        hooks.nixpkgs-fmt.enable = true;
      };
    };

    deprecated-gets-prefixed-test = {
      expectedHooks = [ "pre-push" ];
      conf.hooks.nixpkgs-fmt = {
        enable = true;
        stages = [ "pre-push" ];
      };
    };
  };

  executeTest = lib.mapAttrsToList
    (name: test:
      let runDerivation = run ({ src = null; addGcRoot = false; } // test.conf);
      in ''
        rm -f ~/.git/hooks/*
        ${runDerivation.shellHook}
        actualHooks=(`find ~/.git/hooks -type f -printf "%f "`)
        read -a expectedHooks <<< "${builtins.toString test.expectedHooks}"
        if ! assertArraysEqual actualHooks expectedHooks; then
          echo "${name} failed: Expected hooks '${builtins.toString test.expectedHooks}' but found '$actualHooks'."
          return 1
        fi
      '')
    tests;
in
runCommand "installation-test" { nativeBuildInputs = [ git perl coreutils mktemp ]; } ''
  set -eoux

  HOME=$(mktemp -d)
  cd $HOME
  git init

  assertArraysEqual() {
    local -n _array_one=$1
    local -n _array_two=$2
    diffArray=(`echo ''${_array_one[@]} ''${_array_two[@]} | tr ' ' '\n' | sort | uniq -u`)
    if [ ''${#diffArray[@]} -eq 0 ]
    then
      return 0
    else
      return 1
    fi
  }

  ${lib.concatStrings executeTest}

  echo "success" > $out
''
