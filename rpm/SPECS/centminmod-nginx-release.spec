Name:           centminmod-nginx-release
Version:        1
Release:        1
Summary:        Centmin Mod Nginx RPM repository configuration
License:        BSD-2-Clause
URL:            https://rpm-nginx.centminmod.com
BuildArch:      noarch
Source0:        centminmod-nginx.repo
Source1:        RPM-GPG-KEY-centminmod-nginx

%description
Repository configuration and GPG signing public key for the Centmin Mod
Nginx RPM repository (rpm-nginx.centminmod.com). Installing this package
configures dnf/yum with gpgcheck and repo_gpgcheck enabled.

%prep

%build

%install
install -D -p -m 0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/centminmod-nginx.repo
install -D -p -m 0644 %{SOURCE1} %{buildroot}%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-centminmod-nginx

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/centminmod-nginx.repo
%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-centminmod-nginx

%changelog
* Fri Jul 04 2026 Centmin Mod <rpm-signing@centminmod.com> - 1-1
- Initial release package: repository config + GPG public key
