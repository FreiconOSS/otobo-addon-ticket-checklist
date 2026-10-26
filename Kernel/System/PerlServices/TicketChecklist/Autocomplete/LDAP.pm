# --
# Kernel/System/PerlServices/TicketChecklist/Autocomplete/LDAP.pm - LDAP backend for responsible autocomplete
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Autocomplete::LDAP;

use strict;
use warnings;

use Net::LDAP;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::User
    Kernel::System::Valid
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklist::Autocomplete::LDAP - backend for responsible autocomplete

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    my $Config = $ConfigObject->Get('TicketChecklist::ResponsibleLDAP') || {};
    $Self->{Config} = $Config;

    # max shown user a search list
    $Self->{UserSearchListLimit} = $Config->{UserSearchListLimit} || 200;

    # get ldap preferences
    $Self->{Die} = 0;
    if ( defined $Config->{Params}->{Die} ) {
        $Self->{Die} = $Config->{Params}->{Die};
    }

    # params
    if ( $Config->{Params}->{Params} ) {
        $Self->{Params} = $Config->{Params}->{Params};
    }

    # host
    if ( $Config->{Params}->{Host} ) {
        $Self->{Host} = $Config->{Params}->{Host};
    }
    else {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need TicketChecklist::ResponsibleLDAP->Params->Host in Kernel/Config.pm',
        );
        return;
    }

    # base dn
    if ( defined $Config->{Params}->{BaseDN} ) {
        $Self->{BaseDN} = $Config->{Params}->{BaseDN};
    }
    else {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need TicketChecklist::ResponsibleLDAP->Params->BaseDN in Kernel/Config.pm',
        );
        return;
    }

    # scope
    if ( $Config->{Params}->{SSCOPE} ) {
        $Self->{SScope} = $Config->{Params}->{SSCOPE};
    }
    else {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need TicketChecklist::ResponsibleLDAP->Params->SSCOPE in Kernel/Config.pm',
        );
        return;
    }

    # search user
    $Self->{SearchUserDN} = $Config->{Params}->{UserDN} || '';
    $Self->{SearchUserPw} = $Config->{Params}->{UserPw} || '';

    # group dn
    $Self->{GroupDN} = $Config->{Params}->{GroupDN} || '';
    # customer key
    if ( $Config->{UserKey} ) {
        $Self->{UserKey} = $Config->{UserKey};
    }
    else {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need TicketChecklist::ResponsibleLDAP->UserKey in Kernel/Config.pm',
        );
        return;
    }

    # ldap filter always used
    $Self->{AlwaysFilter} = $Config->{Params}->{AlwaysFilter} || '';

    $Self->{SearchPrefix} = $Config->{UserSearchPrefix};
    if ( !defined $Self->{SearchPrefix} ) {
        $Self->{SearchPrefix} = '';
    }
    $Self->{SearchSuffix} = $Config->{UserSearchSuffix};
    if ( !defined $Self->{SearchSuffix} ) {
        $Self->{SearchSuffix} = '*';
    }

    # charset settings
    $Self->{SourceCharset} = $Config->{Params}->{SourceCharset} || '';

    # set cache type
    $Self->{CacheType} = 'ResponsibleLDAP';

    # create cache object, but only if CacheTTL is set in customer config
    if ( $Config->{CacheTTL} ) {
        $Self->{CacheObject} = $Kernel::OM->Get('Kernel::System::Cache');
    }

    # get valid filter if used
    $Self->{ValidFilter} = $Config->{UserValidFilter} || '';

    # connect first if Die is enabled, make sure that connection is possible, else die
    if ( $Self->{Die} ) {
        return if !$Self->_Connect();
    }

    return $Self;
}

=item ResponsibleSearch()

=cut

sub ResponsibleSearch {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Needed ( qw(Term) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my %Users = $Self->_UserSearch(
        Search => $Param{Term},
    );

    my %PossibleResponsibles;
    for my $UserID ( keys %Users ) {
        my %UserData = $Self->GetUserData(
            User => $UserID,
        );

        $PossibleResponsibles{$UserID} = \%UserData;
    }

    return \%PossibleResponsibles;
}

=item MemberOfList()

=cut

sub MemberOfList {
    my ( $Self, %Param ) = @_;

    return $Param{UserLogin};
}

=item KeyAttributeGet()

=cut

sub KeyAttributeGet {
    my ( $Self, %Param ) = @_;

    return $Self->{UserKey};
}

sub Fullname {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    # check needed stuff
    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin!'
        );
        return;
    }

    # build filter
    my $Filter = "($Self->{UserKey}=$Param{UserLogin})";

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # check cache
    my $Name = '';
    if ( $Self->{CacheObject} ) {
        my $Name = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => 'TicketChecklist::ResponsibleLDAP::Fullname::' . $Param{UserLogin},
        );
        return $Name if defined $Name;
    }

    # create ldap connect
    return if !$Self->_Connect();

    # perform user search
    my $Result = $Self->{LDAP}->search(
        base      => $Self->{BaseDN},
        scope     => $Self->{SScope},
        filter    => $Filter,
        sizelimit => $Self->{UserSearchListLimit},
        attrs     => $Self->{Config}->{UserNameFields},
    );

    if ( $Result->code() ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Search failed! ' . $Result->error(),
        );
        return;
    }

    for my $Entry ( $Result->all_entries() ) {

        for my $Field ( @{ $Self->{Config}->{UserNameFields} } ) {

            if ( defined $Entry->get_value($Field) ) {

                if ( !$Name ) {
                    $Name = $Self->_ConvertFrom( $Entry->get_value($Field) );
                }
                else {
                    $Name .= ' ' . $Self->_ConvertFrom( $Entry->get_value($Field) );
                }
            }
        }
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => 'TicketChecklist::ResponsibleLDAP::Fullname::' . $Param{UserLogin},
            Value => $Name,
            TTL   => $Self->{UserMap}->{CacheTTL},
        );
    }

    return $Name;
}

sub _UserSearch {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    # check needed stuff
    if ( !$Param{Search} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need Search!'
        );
        return;
    }

    # build filter
    my $Filter = '';
    my $Count = 0;
    my @Parts = split( /\+/, $Param{Search}, 6 );
    for my $Part (@Parts) {

        $Part = $Self->{SearchPrefix} . $Part . $Self->{SearchSuffix};
        $Part =~ s/(\%+)/\%/g;
        $Part =~ s/(\*+)\*/*/g;
        $Count++;

        if ( $Self->{Config}->{UserSearchFields} ) {
            $Filter .= '(|';
            for my $Field ( @{ $Self->{Config}->{UserSearchFields} } ) {
                $Filter .= "($Field=" . $Self->_ConvertTo($Part) . ")";
            }
            $Filter .= ')';
        }
        else {
            $Filter .= "($Self->{UserKey}=$Part)";
        }
    }
    if ( $Count > 1 ) {
        $Filter = "(&$Filter)";
    }

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # add valid filter
    if ( $Self->{ValidFilter} ) {
        $Filter = "(&$Filter$Self->{ValidFilter})";
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Users = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => 'TicketChecklist::ResponsibleLDAP::' . $Filter,
        );
        return %{$Users} if ref $Users eq 'HASH';
    }

    # create ldap connect
    return if !$Self->_Connect();

    # combine needed attrs
    my @Attributes = ( @{ $Self->{Config}->{UserListFields} }, $Self->{UserKey} );

    # perform user search
    my $Result = $Self->{LDAP}->search(
        base      => $Self->{BaseDN},
        scope     => $Self->{SScope},
        filter    => $Filter,
        sizelimit => $Param{Limit} || $Self->{UserSearchListLimit},
        attrs     => \@Attributes,
    );

    # log ldap errors
    if ( $Result->code() ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => $Result->error(),
        );
    }

    my %Users;
    for my $Entry ( $Result->all_entries() ) {

        my $UserString = '';

        for my $Field ( @{ $Self->{Config}->{UserListFields} } ) {

            my $Value = $Self->_ConvertFrom( $Entry->get_value($Field) );

            if ($Value) {
                if ( $Field =~ /^targetaddress$/i ) {
                    $Value =~ s/SMTP:(.*)/$1/;
                }
                $UserString .= $Value . ' ';
            }
        }

        $UserString =~ s/^(.*)\s(.+?\@.+?\..+?)(\s|)$/"$1" <$2>/;

        if ( defined $Entry->get_value( $Self->{UserKey} ) ) {
            $Users{ $Self->_ConvertFrom( $Entry->get_value( $Self->{UserKey} ) ) } = $UserString;
        }
    }

    # check if user need to be in a group!
    if ( $Self->{GroupDN} ) {

        for my $Filter2 ( sort keys %Users ) {

            my $Result2 = $Self->{LDAP}->search(
                base      => $Self->{GroupDN},
                scope     => $Self->{SScope},
                filter    => 'memberUid=' . $Filter2,
                sizelimit => $Param{Limit} || $Self->{UserSearchListLimit},
                attrs     => ['1.1'],
            );

            if ( !$Result2->all_entries() ) {
                delete $Users{$Filter2};
            }
        }
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => 'TicketChecklist::ResponsibleLDAP::' . $Filter,
            Value => \%Users,
            TTL   => $Self->{Config}->{CacheTTL},
        );
    }

    return %Users;
}

sub _ConvertFrom {
    my ( $Self, $Text ) = @_;

    return if !defined $Text;

    if ( !$Self->{SourceCharset} ) {
        return $Text;
    }

    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Self->{SourceCharset},
        To   => 'utf-8',
    );
}

sub GetUserData {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if ( !$Param{User} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need User!'
        );
        return;
    }

    # perform user search
    my @Attributes;
    for my $Entry ( @{ $Self->{Config}->{Map} } ) {
        push( @Attributes, $Entry->[2] );
    }
    my $Filter = "($Self->{UserKey}=$Param{User})";

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Data = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => 'TicketChecklist::ResponsibleLDAP::UserDataGet::' . $Param{User},
        );
        return %{$Data} if ref $Data eq 'HASH';
    }

    # create ldap connect
    return if !$Self->_Connect();

    # perform search
    my $Result = $Self->{LDAP}->search(
        base   => $Self->{BaseDN},
        scope  => $Self->{SScope},
        filter => $Filter,
        attrs  => \@Attributes,
    );
    # log ldap errors
    if ( $Result->code() ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => $Result->error(),
        );
        return;
    }

    # get first entry
    my $Result2 = $Result->entry(0);
    if ( !$Result2 ) {
        return;
    }

    # get customer user info
    my %Data;
    for my $Entry ( @{ $Self->{Config}->{Map} } ) {

        my $Value = $Self->_ConvertFrom( $Result2->get_value( $Entry->[2] ) ) || '';

        if ( $Value && $Entry->[2] =~ /^targetaddress$/i ) {
            $Value =~ s/SMTP:(.*)/$1/;
        }

        $Data{ $Entry->[0] } = $Value;
    }

    return if !$Data{UserLogin};

    # compat!
    $Data{UserID}             = $Data{UserLogin};
    $Data{ $Self->{UserKey} } = $Data{UserLogin};
    $Data{UserFullname}       = $Self->Fullname( UserLogin => $Data{UserLogin} );

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => 'TicketChecklist::ResponsibleLDAP::UserDataGet::' . $Param{User},
            Value => { %Data },
            TTL   => $Self->{Config}->{CacheTTL},
        );
    }

    return %Data;
}

sub _Connect {
    my ( $Self, %Param ) = @_;

    # return if connection is already open
    return 1 if $Self->{LDAP};

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
    $Self->{LDAP} = Net::LDAP->new( $Self->{Host}, %{ $Self->{Params} } );

    if ( !$Self->{LDAP} ) {
        if ( $Self->{Die} ) {
            die "Can't connect to $Self->{Host}: $@";
        }
        else {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Can't connect to $Self->{Host}: $@",
            );
            return;
        }
    }

    my $Result;
    if ( $Self->{SearchUserDN} && $Self->{SearchUserPw} ) {
        $Result = $Self->{LDAP}->bind(
            dn       => $Self->{SearchUserDN},
            password => $Self->{SearchUserPw},
        );
    }
    else {
        $Result = $Self->{LDAP}->bind();
    }

    if ( $Result->code() ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'First bind failed! ' . $Result->error(),
        );
        $Self->{LDAP}->disconnect();
        return;
    }

    return 1;
}

sub _ConvertTo {
    my ( $Self, $Text, $Charset ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    if ( !$Charset || !$Self->{DestCharset} ) {
        $EncodeObject->EncodeInput( \$Text );
        return $Text;
    }

    # convert from input charset ($Charset) to directory charset ($Self->{DestCharset})
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Charset,
        To   => $Self->{DestCharset},
    );
}

=item Lookup()

=cut

sub Lookup {
    my ($Self, %Param) = @_;

    return $Param{UserLogin};
}


1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

