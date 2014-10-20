#/usr/bin/perl
use Mojolicious::Lite;
use Mojo::Pg;
use 5.20.1;
use experimental 'signatures';

app->config({
	hypnotoad => {
		listen  => ['http://localhost:3000'],
		workers => 10,
		proxy   => 1
	}
});

helper pg => sub { state $pg = Mojo::Pg->new('postgresql://user:pass@localhost/storage') };

app->pg->db->do(
	'create table if not exists paste(
		id uuid default uuid_generate_v4(),
		content text,
		primary key(id)
	)'
);

get '/' => sub ($c) {
	$c->render('index');
} => 'index';

get '/p' => sub ($c) {
	$c->render('paste');
} => 'paste';

post '/p/save' => sub ($c) {
	my $db = $c->pg->db;
	my $paste = $c->param('paste');
	my $res = $db->query('insert into paste(content) values (?) returning id' => $paste);
	$c->redirect_to("/p/" . $res->hash->{id});
} => 'pastesave';

get '/p/:id' => sub ($c) {
	my $db = $c->pg->db;
	my $id = $c->param('id');
	return $c->reply->not_found unless $id =~ /^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$/i;
	my $res = $db->query('select content from paste where id = (?)' => $id)->hash;
	return $c->reply->not_found unless $res;
	$c->stash(content => $res->{content});
	$c->render('paste/show');
} => 'pasteshow';

app->start;
