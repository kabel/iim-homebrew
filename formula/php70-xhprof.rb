require File.expand_path("../../Abstract/abstract-php-extension", __FILE__)

class Php70Xhprof < AbstractPhp70Extension
  init
  homepage "https://github.com/phacility/xhprof"
  head "https://github.com/tony2001/xhprof.git", :branch => "badoo-7.0"

  depends_on "pkg-config" => :build

  def install
    Dir.chdir "extension" do
      ENV.universal_binary if build.universal?

      safe_phpize
      system "./configure", "--prefix=#{prefix}",
                            phpconfig
      system "make"
      prefix.install "modules/xhprof.so"
    end

    prefix.install %w[xhprof_html xhprof_lib]
    write_config_file if build.with? "config-file"
  end
end
