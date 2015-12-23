class Httpd24 < Formula
  desc "HTTP server"
  homepage "https://httpd.apache.org/"
  url "https://archive.apache.org/dist/httpd/httpd-2.4.18.tar.bz2"
  sha256 "0644b050de41f5c9f67c825285049b144690421acb709b06fe53eddfa8a9fd4c"

  bottle do
    revision 1
    sha256 "e42f84b204594b68e19a7881cf298db5a48d3246b611c5b1657754e2b1fbb97e" => :el_capitan
    sha256 "7cf68e02a013b9779eb7b5f4391881f74d803c6cccd90895806ddcf108338624" => :yosemite
    sha256 "6ac23f6e09c8ac706e952a8a0aa88ef4649cf8aafd91927723168a61c680e985" => :mavericks
  end

  conflicts_with "homebrew/apache/httpd22", :because => "different versions of the same software"

  skip_clean :la

  option "with-mpm-worker", "Use the Worker Multi-Processing Module instead of Prefork"
  option "with-mpm-event", "Use the Event Multi-Processing Module instead of Prefork"
  option "with-privileged-ports", "Use the default ports 80 and 443 (which require root privileges), instead of 8080 and 8443"
  option "with-ldap", "Include support for LDAP"
  option "with-http2", "Build and enable the HTTP/2 shared Module"

  depends_on "openssl"
  depends_on "pcre"
  depends_on "homebrew/dupes/zlib"

  if build.with? "ldap"
    depends_on "apr-util" => "with-openldap"
  else
    depends_on "apr-util"
  end

  if build.with? "http2"
    depends_on "nghttp2"
  end

  if build.with?("mpm-worker") && build.with?("mpm-event")
    raise "Cannot build with both worker and event MPMs, choose one"
  end

  def install
    # point config files to opt_prefix instead of the version-specific prefix
    inreplace "Makefile.in",
      '#@@ServerRoot@@#$(prefix)#', '#@@ServerRoot@@'"##{opt_prefix}#"

    # fix non-executable files in sbin dir (for brew audit)
    inreplace "support/Makefile.in",
      '$(DESTDIR)$(sbindir)/envvars', '$(DESTDIR)$(sysconfdir)/envvars'
    inreplace "support/Makefile.in",
      'envvars-std $(DESTDIR)$(sbindir);', 'envvars-std $(DESTDIR)$(sysconfdir);'
    inreplace "support/apachectl.in",
      '@exp_sbindir@/envvars', "#{etc}/apache2/2.4/envvars"

    # install custom layout
    File.open("config.layout", "w") { |f| f.write(httpd_layout) }

    args = %W[
      --enable-layout=Homebrew
      --enable-mods-shared=all
      --enable-unique-id
      --enable-ssl
      --enable-dav
      --enable-cache
      --enable-logio
      --enable-deflate
      --enable-cgi
      --enable-cgid
      --enable-suexec
      --enable-rewrite
      --with-apr=#{Formula["apr"].opt_prefix}
      --with-apr-util=#{Formula["apr-util"].opt_prefix}
      --with-pcre=#{Formula["pcre"].opt_prefix}
      --with-ssl=#{Formula["openssl"].opt_prefix}
      --with-z=#{Formula["zlib"].opt_prefix}
    ]

    if build.with? "mpm-worker"
      args << "--with-mpm=worker"
    elsif build.with? "mpm-event"
      args << "--with-mpm=event"
    else
      args << "--with-mpm=prefork"
    end

    if build.with? "privileged-ports"
      args << "--with-port=80" << "--with-sslport=443"
    else
      args << "--with-port=8080" << "--with-sslport=8443"
    end

    if build.with? "http2"
      args << "--enable-http2" << "--with-nghttp2=#{Formula["nghttp2"].opt_prefix}"
    end

    if build.with? "ldap"
      args << "--with-ldap" << "--enable-ldap" << "--enable-authnz-ldap"
    end

    (etc/"apache2/2.4").mkpath

    system "./configure", *args

    system "make"
    system "make", "install"
    (var/"apache2/log").mkpath
    (var/"apache2/run").mkpath
    touch("#{var}/log/apache2/access_log") unless File.exist?("#{var}/log/apache2/access_log")
    touch("#{var}/log/apache2/error_log") unless File.exist?("#{var}/log/apache2/error_log")
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/httpd</string>
        <string>-D</string>
        <string>FOREGROUND</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  def httpd_layout
    <<-EOS.undent
      <Layout Homebrew>
          prefix:        #{prefix}
          exec_prefix:   ${prefix}
          bindir:        ${exec_prefix}/bin
          sbindir:       ${exec_prefix}/bin
          libdir:        ${exec_prefix}/lib
          libexecdir:    ${exec_prefix}/libexec
          mandir:        #{man}
          sysconfdir:    #{etc}/apache2/2.4
          datadir:       #{var}/www
          installbuilddir: ${prefix}/build
          errordir:      ${datadir}/error
          iconsdir:      ${datadir}/icons
          htdocsdir:     ${datadir}/htdocs
          manualdir:     ${datadir}/manual
          cgidir:        #{var}/apache2/cgi-bin
          includedir:    ${prefix}/include/httpd
          localstatedir: #{var}/apache2
          runtimedir:    #{var}/run/apache2
          logfiledir:    #{var}/log/apache2
          proxycachedir: ${localstatedir}/proxy
      </Layout>
    EOS
  end

  def caveats
    if build.with? "privileged-ports"
      <<-EOS.undent
      To load #{name} when --with-privileged-ports is used:
          sudo cp -v #{plist_path} /Library/LaunchDaemons
          sudo chown -v root:wheel /Library/LaunchDaemons/#{plist_path.basename}
          sudo chmod -v 644 /Library/LaunchDaemons/#{plist_path.basename}
          sudo launchctl load /Library/LaunchDaemons/#{plist_path.basename}

      To reload #{name} after an upgrade when --with-privileged-ports is used:
          sudo launchctl unload /Library/LaunchDaemons/#{plist_path.basename}
          sudo launchctl load /Library/LaunchDaemons/#{plist_path.basename}

      If not using --with-privileged-ports, use the instructions below.
      EOS
    end
  end

  test do
    system bin/"httpd", "-v"
  end
end
