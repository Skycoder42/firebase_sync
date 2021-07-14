#!/bin/sh
set -ex

echo '#!/bin/sh' >.git/hooks/pre-commit
echo -e 'exec dart run dart_pre_commit -tpo any --ansi' >>.git/hooks/pre-commit
chmod a+x .git/hooks/pre-commit
