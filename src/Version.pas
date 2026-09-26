{ The port's version, MAJOR.MINOR.PATCH.

  One constant, changed only by tools/bump-version.sh, so the number and the
  commit that carries it cannot drift apart:

    patch   +0.0.1 with every commit
    minor   +0.1.0 at a milestone the developer names; patch goes back to 0

  See "Versioning" in README.md. }

unit Version;

{$MODE DELPHI}{$H+}

interface

const
  APP_NAME = 'Akuji the Demon';
  APP_VERSION = '2.0.2';

implementation

end.
