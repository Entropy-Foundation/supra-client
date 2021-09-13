#!/usr/bin/env sh

main()  {
  subkey generate-node-key > node-key 2>&1 && supra --node-key="$(tail -1 node-key)" "$@"
}

main "$@"
