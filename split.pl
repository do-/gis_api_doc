use utf8;
use File::Path qw (make_path remove_tree);
use File::Copy;
use Data::Dumper;
binmode (STDOUT, ":utf8");

main ();

################################################################################

my %page = ();

sub main {
	clean_up ();
	write_pages ();
	decorate ($_) foreach (values %page);
	complete ($_) foreach (values %page);
	append_css ();
	print_index ();
	copy_images ();
	warn "Done.\n";
}

################################################################################

my %ref = ();
my $prefix;
my $is_open = 0;
my $last_line;
my $version;
my $depth_html=0;
my $depth_css=0;

################################################################################

sub copy_images {
	my $src = 'src/resource';
	opendir (DIR, $src) or die "Can't opendir $src: $!\n";
	warn "Copying images...\n";
	foreach (map {"$src/$_"} grep {/(gif|png)$/} readdir (DIR)) {
		my $from = $_;
		my $to = $from;
		$to =~ s{$src}{target/img};
		File::Copy::copy ($from, $to);
	}
	closedir DIR;
}

################################################################################

sub write_pages {
	my $src = 'src';
	opendir (DIR, $src) or die "Can't opendir $src: $!\n";
	split_html ($_) foreach (map {"$src/$_"} grep {/html$/} readdir (DIR));
	closedir DIR;
}

################################################################################

sub clean_up {
	warn "Cleaning up...\n";
	remove_tree ('target/ws');
	remove_tree ('target/xs');
	remove_tree ('target/css');
	remove_tree ('target/img');
	make_path   ('target/css');
	make_path   ('target/img');
}

################################################################################

sub print_index {

	my $fn = "target/index.html";
	open (O, ">:encoding(UTF-8)", $fn) or die "Can't write to $fn: $!\n";	
	warn "Generating index...\n";

	print_head ({label => 'API ГИС ЖКХ'});
	print O "<table cellspacing=0 class=reference>";

	my $last_srv;
	foreach my $path (sort grep /^ws/, keys %page) {
	
		my ($pre, $srv, $meth) = split /\W/, $path;

		next if $srv !~ /Async$/ or $meth eq 'index';

		if ($last_srv ne $srv) {
			my $p = "ws/$srv/index.html";
			print O qq {<tr><td class=toc><a href="/$p">$srv</a></td><td class=toc>$page{$p}->{remark}</td></tr>};
			$last_srv = $srv;
		}

		print O qq {<tr><td><a href="/$path">$srv.$meth</a></td><td>$page{$path}->{remark}</td></tr>};

	}	

	print O "</table>";
	close (O);

}

################################################################################

sub append_css {

	my $fn = "target/css/style.css";
	open (O, ">>:encoding(UTF-8)", $fn) or die "Can't append to $fn: $!\n";
	warn "Fixing CSS...\n";

	for (my $i = $depth_css + 1; $i < $depth_html; $i ++) {
		my $px = 10 * (1 + $i);
		print O "tr.startGroup$i td.first {padding-left:$px;}\n";
		print O "tr.group$i td.first {padding-left:$px;}\n";
	}

	close (O);

}

################################################################################

sub complete {

	my ($page) = @_;

	my $fn = "target/$page->{path}";
	open (O, ">>:encoding(UTF-8)", $fn) or die "Can't append to $fn: $!\n";	
	warn "Completing $page->{path}...\n";

	print_back_refs (keys %{$page -> {references}});
	print O "</body></html>";

	close (O);
	
}

################################################################################

sub print_back_refs {
	
	@_ > 0 or return;
		
	print O "<h5>Сюда ссылаются</h5></div><ul>\n";
	
	foreach my $p (sort {$a -> {label} cmp $b -> {label}} map {$page {$_}} @_) {
	
		print O qq{<li><a href="/$p->{path}">$p->{label}</a></li>\n};
	
	}
	
	print O "</ul>";

}

################################################################################

sub decorate {

	my ($page) = @_;
	
	my $fn = "target/$page->{path}";
	-f $fn and return warn "Skipping $page->{path}.\n";
	
	open (O, ">:encoding(UTF-8)", $fn) or die "Can't write to $fn: $!\n";
	
	chop $fn;
	open (I, "<:encoding(UTF-8)", $fn) or die "Can't open $fn: $!\n";
	
	warn "Decorating $page->{path}...\n";
	
	print_head ($page);	
	while (my $line = <I>) {print_relinked ($line, $page);}

	close (I);
	close (O);
	
	unlink ($fn);
		
}

################################################################################

sub print_head {

	my ($page) = @_;
	
	print O qq {<html>
		<head>
			<title>$page->{label}</title>
			<link href="/css/style.css" rel="stylesheet" type="text/css">
		</head>
		<body>
			<div class="title">
				<h5><a href="/">API ГИС ЖКХ $version</a></h5>
	};
	
	if ($page -> {path} =~ m{ws/(\w+)/}) {
			
		print O qq {<h5>Сервис: <a href="/ws/$1/">$1</a></h5>} if $' ne 'index.html' #'
			
	}
	
}

################################################################################

sub print_relinked {

	my ($line, $this_page) = @_;
	
	if ($this_page -> {path} =~ /^ws/ and !$this_page -> {remark}) {
	
		if ($line =~ /^\s*<h5>Описание<\/h5>/) {
			$this_page -> {has_remark} = 1;
		}
		elsif ($this_page -> {has_remark} and $line =~ /^\s*<p>(.*?)<\/p>/) {
			$this_page -> {remark} = $1;
		}
	
	}
		
	foreach my $chunk (split /(href="#.*?")/, $line) {

		if ($chunk =~ /href="#(.*?)"/) {
			my $href = $ref {$1} or warn "$1 not found\n";
			my $that_page = $page {$href} or die "Page not found by href: '$href'\n";
			$that_page -> {references} -> {$this_page -> {path}} = 1;
			print O qq {href="/$href"}
		}
		else {		
			$chunk =~ s{src="resource/}{src="/img/};			
			print O $chunk;		
		}

	}

}

################################################################################

sub split_html {

	my ($path) = @_;
	open (I, "<:encoding(UTF-8)", $path) or die "Can't open $path: $!\n";
	
	my $fn = "target/css/style.css";
	my $css = -f $fn ? -1 : 0;

	while (my $line = <I>) {
	
		if (!$version and $line =~ /API v.(.*?)<\/title>/) {
			$version = $1;
			next;
		}
		
		if ($css == 0) {
		
			if ($line =~ /^\s*<style/) {
				open (CSS, ">:encoding(UTF-8)", $fn) or die "Can't write to $fn $!\n";
				$css = 1;
			}
			
		}
		elsif ($css == 1) {

			if ($line =~ /^\s*<\/style/) {
				close (CSS);
				$css = -1;
			}
			else {
			
				$line =~ s{url\(resource}{url\(/img};
			
				if ($line =~ /^tr\.group(\d+)/) {
					$depth_css >= $1 or $depth_css = $1;
				}
				
				print CSS $line;
				
			}

		}
		else {
			$line =~ /^\s*<h[345]>(.*?)<\/h[345]>$/ and check_header ($1);

			if ($is_open) {

				if ($line =~ /^\s*<tr class="group(\d+)"/) {
					$depth_html >= $1 or $depth_html = $1;
				}

				print O $line;

			}
			
			$last_line = $line;

		}

	}

	close (O);
	close (I);

}

################################################################################

sub check_header {

	my ($header) = @_;
	my $path = to_path ($header) or return;
	$last_line =~ /a name="(.*?)"/ or return;		
	
	start_file ({
		path => "$prefix/$path",
		bookmark => $1,
		label => $header,
	});
	
}

################################################################################

sub start_file {

	my ($page) = @_;
	
	$ref {$page -> {bookmark}} = $page -> {path};
	$page {$page -> {path}} = $page;
	
	close (O) if $is_open;
	
	my $fn = "target/$page->{path}";
	chop $fn;
	
	my @parts = split '/', $fn;	
	pop @parts;	
	my $dir = join '/', @parts;
		
	make_path $dir;
	open (O, ">:encoding(UTF-8)", $fn) or die "Can't write to $fn: $!\n";
	warn "Writing $fn...\n";
	$is_open = 1;

}

################################################################################

sub to_path {

	my ($header) = @_;		
	
	$header =~ /^Описание/            ? undef:
	$header =~ /^Список /             ? undef:	
	$header =~ /^Параметры/           ? undef:	
	$header =~ /^Структура/           ? undef:	
	$header =~ /^Выходные/            ? undef:	
	$header =~ /^Ошибки/              ? undef:	
	$header =~ /^Унаследован от/      ? undef:	
	$header =~ /^Ограничения/         ? undef:	
	$header =~ /^Возможные значения/  ? undef:
	$header =~ /^Тип/                 ? undef:
	
	$header =~ / Веб-сервис$/         ? switch_prefix (ws => $`):
	$header =~ / XML-схема$/          ? switch_prefix (xs => $`):
	$header =~ /^Метод: /             ? "$'.html":
	$header =~ /^Методы: /            ? undef:
	$header =~ /^Комплексные типы/    ? "ct/index.html":
	$header =~ /^Комплексный тип: /   ? "ct/$'.html":
	$header =~ /^Простые типы/        ? "st/index.html":
	$header =~ /^Простой тип: /       ? "st/$'.html":
	$header =~ /^Атрибуты/            ? "at/index.html":
	$header =~ /^Атрибут: /           ? "at/" . parse_el ($') . ".html":
	$header =~ /^Элементы/            ? "el/index.html":
	$header =~ /^Элемент: /           ? "el/" . parse_el ($') . ".html":
	die "WTF '$header'?!!\n";

}

################################################################################

sub parse_el {
	my ($name) = @_;
	$name =~ / \[(type|element) (.*?)\]/ or return $name;
	return "$2/$`";
}

################################################################################

sub switch_prefix {
	my ($pre, $name) = @_;
	$name =~ s{[^A-Za-z0-9/]}{_}gsm;
	$prefix = "$pre/$name";
	return 'index.html';
}