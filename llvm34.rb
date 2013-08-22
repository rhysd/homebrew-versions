require 'formula'

class Clang < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/clang.git'
  version   '3.4'
end

class ClangToolsExtra < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/clang-tools-extra.git'
  version   '3.4'
end

class CompilerRt < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/compiler-rt.git'
  version   '3.4'
end

class Polly < Formula
  homepage  'http://llvm.org'
  head      'http://llvm.org/git/polly.git'
  version   '3.4'
end

class Libcxx < Formula
  homepage  'http://llvm.org'
  head      'http://llvm.org/git/libcxx.git'
  version   '3.4'
end

class Llvm34 < Formula
  homepage  'http://llvm.org/'
  head      'http://llvm.org/git/llvm.git'
  version   '3.4'

  option :universal
  option 'with-libcxx', 'Build libc++ standard library support'
  option 'with-clang', 'Build Clang C/ObjC/C++ frontend'
  option 'with-asan', 'Include support for -faddress-sanitizer (from compiler-rt)'
  option 'disable-shared', "Don't build LLVM as a shared library"
  option 'all-targets', 'Build all target backends'
  option 'rtti', 'Build with C++ RTTI'
  option 'disable-assertions', 'Speeds up LLVM, but provides less debug information'

  depends_on :python => :recommended
  depends_on 'gmp4'
  depends_on 'isl011'
  depends_on 'cloog018'

  env :std if build.universal?

  def install
    if python and build.include? 'disable-shared'
      raise 'The Python bindings need the shared library.'
    end

    Clang.new('clang').brew do
      (buildpath/'tools/clang').install Dir['*']
    end if build.with? 'clang'

    ClangToolsExtra.new('clang-tools-extra').brew do
      (buildpath/'tools/clang/tools/extra').install Dir['*']
    end if build.with? 'clang'

    CompilerRt.new("compiler-rt").brew do
      (buildpath/'projects/compiler-rt').install Dir['*']
    end if build.with? 'asan'

    Libcxx.new('libcxx').brew do
      (buildpath/'projects/libcxx').install Dir['*']
    end if build.with? 'libcxx'

    Polly.new('polly').brew do
      (buildpath/'tools/polly').install Dir['*']
    end

    if build.universal?
      ENV['UNIVERSAL'] = '1'
      ENV['UNIVERSAL_ARCH'] = 'i386 x86_64'
    end

    ENV['REQUIRES_RTTI'] = '1' if build.include? 'rtti'

    install_prefix = lib/"llvm-#{version}"

    args = [
      "--prefix=#{install_prefix}",
      "--enable-optimized",
      # As of LLVM 3.1, attempting to build ocaml bindings with Homebrew's
      # OCaml 3.12.1 results in errors.
      "--disable-bindings",
      "--with-gmp=#{Formula.factory('gmp4').opt_prefix}",
      "--with-isl=#{Formula.factory('isl011').opt_prefix}",
      "--with-cloog=#{Formula.factory('cloog018').opt_prefix}"
    ]

    if build.include? 'all-targets'
      args << '--enable-targets=all'
    else
      args << '--enable-targets=host'
    end
    args << "--enable-shared" unless build.include? 'disable-shared'

    args << "--disable-assertions" if build.include? 'disable-assertions'

    system './configure', *args
    system 'make', 'VERBOSE=1'
    system 'make', 'VERBOSE=1', 'install'

    # Putting libcxx in projects only ensures that headers are installed.
    # Manually "make install" to actually install the shared libs.
    cd buildpath/'projects/libcxx' do
      libcxx_make_args = [
        # The following flags are needed so it can be installed correctly.
        "DSTROOT=#{install_prefix}",
        "SYMROOT=#{buildpath}/projects/libcxx"
      ]
      system 'make', 'install', *libcxx_make_args
    end if build.with? 'libcxx'

    # Install Clang tools
    (share/"clang-#{version}/tools").install buildpath/'tools/clang/tools/scan-build', buildpath/'tools/clang/tools/scan-view' if build.with? 'clang'

    if python
      # Install llvm python bindings.
      mv buildpath/'bindings/python/llvm', buildpath/"bindings/python/llvm-#{version}"
      python.site_packages.install buildpath/"bindings/python/llvm-#{version}"
      # Install clang tools and bindings if requested.
      if build.with? 'clang'
        mv buildpath/'tools/clang/bindings/python/clang', buildpath/"tools/clang/bindings/python/clang-#{version}"
        python.site_packages.install buildpath/"tools/clang/bindings/python/clang-#{version}"
      end
    end

    # Link executables to bin and add suffix to avoid conflicts
    mkdir_p bin
    Dir.glob(install_prefix/'bin/*') do |exec_path|
      exec_file = File.basename(exec_path)
      ln_s exec_path, bin/"#{exec_file}-#{version}"
    end

    # Also link man pages
    mkdir_p man1
    Dir.glob(install_prefix/'share/man/man1/*') do |manpage|
      manpage_base = File.basename(manpage, '.1')
      ln_s manpage, man1/"#{manpage_base}-#{version}.1"
    end
  end

  def test
    system "#{bin}/llvm-config-#{version}", "--version"
  end

  def caveats
    s = ''
    s += python.standard_caveats if python

    if build.with? 'clang'
      clang_tools_path = HOMEBREW_PREFIX/"share/clang-#{version}"
      s += <<-EOS.undent

      Extra tools are installed in #{clang_tools_path}.
      EOS
    end

    if build.with? 'libcxx'
      include_path = HOMEBREW_PREFIX/"lib/llvm-#{version}/c++/v1"
      libs_path = HOMEBREW_PREFIX/"lib/llvm-#{version}/usr/lib"
      s += <<-EOS.undent

      To link to libc++ built here, please adjust your $CXX as following:
      clang++-#{version} -stdlib=libc++ -nostdinc++ -I#{include_path} -L#{libs_path}
      EOS
    end
    s
  end

end
