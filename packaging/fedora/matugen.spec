# matugen for vela. Fedora's own is older than vela is made for (3.1 on
# Fedora 44; 4.0 added --source-color-index), so vela builds this one and
# bootstrap.sh installs it in place of Fedora's whenever that is older.
#
# Built by .github/workflows/packages.yml, once per Fedora release, onto the
# repo's `packages` release. To move to a new matugen: change Version, put
# Release back to 1, add a changelog entry, and push.
%global debug_package %{nil}

Name:           matugen
Version:        4.2.0
Release:        1%{?dist}
Summary:        Material You and base16 colour scheme generator

License:        GPL-2.0-or-later
URL:            https://github.com/InioX/matugen
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  cargo
BuildRequires:  rust
BuildRequires:  gcc

%description
matugen makes a Material You or base16 colour scheme from an image or a
colour, and writes it into templates. This is the build vela installs, since
Fedora's own matugen predates the 4.0 vela needs.

%prep
%autosetup -n %{name}-%{version}

%build
# --locked: the dependency versions matugen released with, not whatever
# crates.io has newest today.
cargo build --release --locked

%install
install -Dpm0755 target/release/%{name} %{buildroot}%{_bindir}/%{name}

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/%{name}

%changelog
* Mon Sep 28 2026 i-jasmin <189134348+i-jasmin@users.noreply.github.com> - 4.2.0-1
- matugen 4.2.0, for vela
