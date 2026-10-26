# --
# Default configuration for Responsible autocomplete via LDAP.
package Kernel::Config::Files::ZZZChecklist;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = ();

no warnings 'redefine';

sub Load {
    my $File = shift;
    my $Self = shift;

    $Self->{'TicketChecklist::ResponsibleLDAP'} = {
        Params => {
            # ldap host
            Host => 'bay.csuhayward.edu',
            # ldap base dn
            BaseDN => 'ou=seas,o=csuh',
            # search scope (one|sub)
            SSCOPE => 'sub',
            # The following is valid but would only be necessary if the
            # anonymous user does NOT have permission to read from the LDAP tree
            UserDN => '',
            UserPw => '',
            # in case you want to add always one filter to each ldap query, use
            # this option. e. g. AlwaysFilter => '(mail=*)' or AlwaysFilter => '(objectclass=user)'
            AlwaysFilter => '',
            # if the charset of your ldap server is iso-8859-1, use this:
            # SourceCharset => 'iso-8859-1',
            # die if backend can't work, e. g. can't connect to server
            Die => 0,
            # Net::LDAP new params (if needed - for more info see perldoc Net::LDAP)
            Params => {
                port    => 389,
                timeout => 120,
                async   => 0,
                version => 3,
            },
        },
        # customer unique id
        UserKey => 'uid',
        # customer #
        UserListFields => ['cn', 'mail'],
        UserSearchFields => ['uid', 'cn', 'mail'],
        UserSearchPrefix => '',
        UserSearchSuffix => '*',
        UserSearchListLimit => 250,
        UserNameFields => ['givenname', 'sn'],
        # cache time to live in sec. - cache any ldap queries
        CacheTTL => 0,
        Map => [
            # var, frontend, storage, shown (1=always,2=lite), required, storage-type, http-link, readonly
            [ 'UserTitle',      'Title',      'title',           1, 0, 'var', '', 0 ],
            [ 'UserFirstname',  'Firstname',  'givenname',       1, 1, 'var', '', 0 ],
            [ 'UserLastname',   'Lastname',   'sn',              1, 1, 'var', '', 0 ],
            [ 'UserLogin',      'Username',   'uid',             1, 1, 'var', '', 0 ],
            [ 'UserEmail',      'Email',      'mail',            1, 1, 'var', '', 0 ],
            [ 'UserPhone',      'Phone',      'telephonenumber', 1, 0, 'var', '', 0 ],
            [ 'UserAddress',    'Address',    'postaladdress',   1, 0, 'var', '', 0 ],
            [ 'UserComment',    'Comment',    'description',     1, 0, 'var', '', 0 ],
        ],
    };

    return $Self;
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
