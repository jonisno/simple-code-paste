#/usr/bin/perl
use Mojolicious::Lite;
use Math::Base::Convert qw/cnv/;
use Mojo::Pg;
use 5.20.1;
use experimental 'signatures';

plugin 'Config';

app->secrets(app->config('secrets'));

helper pg => sub { state $pg = Mojo::Pg->new(app->config('dsn')) };

helper generate_token => sub {
	my $id = shift;
	return cnv($id + int rand(9999999), 'dec', 'b62');
};

app->pg->db->do(
	'create table if not exists paste(
		id serial,
		token text unique,
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

	# CSRF protection.
	my $val = $c->validation;
	return $c->render(text => 'Invalid CSRF token', status => 403) if $val->csrf_protect->has_error('csrf_token');

	my $res = $db->query('insert into paste(content) values (?) returning id' => $paste);
	my $id = $res->hash->{id};

	# Generate token and make sure it's not already in the database.
	my $token = $c->generate_token($id);
	my $tokencheck = $db->query('select token from paste where token = ?' => $token)->hash;
	while($tokencheck) {
		$token = $c->generate_token($id);
		$tokencheck = $db->query('select token from paste where token = ?' => $token)->hash;
	};

	$db->query('update paste set token = ? where id = ?' => ($token, $id));
	$c->redirect_to("/p/$token");
} => 'pastesave';

get '/p/:token' => sub ($c) {
	my $db = $c->pg->db;
	my $token = $c->param('token');
	my $res = $db->query('select content from paste where token = (?)' => $token)->hash;
	return $c->reply->not_found unless $res;
	$c->stash(content => $res->{content});
	$c->render('paste/show');
} => 'pasteshow';

app->start;
