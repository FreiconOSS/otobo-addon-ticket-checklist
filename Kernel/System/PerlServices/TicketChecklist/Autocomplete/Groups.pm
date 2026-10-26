# --
# Kernel/System/PerlServices/TicketChecklist/Autocomplete/Groups.pm - Groups backend for responsible autocomplete
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Autocomplete::Groups;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::Group
    Kernel::System::User
    Kernel::System::Valid
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklist::Autocomplete::Groups - backend for responsible autocomplete

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

    return $Self;
}

=item ResponsibleSearch()

=cut

sub ResponsibleSearch {
    my ( $Self, %Param ) = @_;

    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

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

    my @Parts = split /\*/, $Param{Term};
    my $Regex = join '.*', map{ quotemeta $_ }@Parts;

    my %GroupsData = $GroupObject->GroupDataList();
    my %PossibleResponsibles;

    GROUPID:
    for my $GroupID ( keys %GroupsData ) {
        my $Group = $GroupsData{$GroupID};

        next GROUPID if $Group->{ValidID} != 1;

        my $Matches;
        $Matches++ if $Group->{Name} =~ m{$Regex};
        $Matches++ if !$Matches && ( $Group->{Comment} // '' ) =~ m{$Regex};

        next GROUPID if !$Matches;

        my %UserData = (
            UserLogin     => $GroupID,
            UserFullname  => $Group->{Name},
            UserID        => $GroupID,
        );

        $PossibleResponsibles{$GroupID} = \%UserData;
    }

    return \%PossibleResponsibles;
}

=item MemberOfList()

=cut

sub MemberOfList {
    my ( $Self, %Param ) = @_;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my %GroupMemberships = $GroupObject->PermissionUserGroupGet(
        UserID => $Param{UserID},
        Type   => 'ro',
    );

    return keys %GroupMemberships;
}


=item KeyAttributeGet()

=cut

sub KeyAttributeGet {
    my ( $Self, %Param ) = @_;

    return 'UserID';
}

=item Fullname()

=cut

sub Fullname {
    my ($Self, %Param) = @_;

    return if !$Param{UserLogin};

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    return $GroupObject->GroupLookup( GroupID => $Param{UserLogin}, %Param );
}

=item GetUserData()

=cut

sub GetUserData {
    my ($Self, %Param) = @_;

    return if !$Param{User};

    my $UserObject     = $Kernel::OM->Get('Kernel::System::User');
    my $GroupObject    = $Kernel::OM->Get('Kernel::System::Group');
    my $LanguageObject = $Kernel::OM->Get('Kernel::Language');
    my $LogObject      = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject     = $Kernel::OM->Get('Kernel::System::Main');

    my $GroupName = $GroupObject->GroupLookup( GroupID => $Param{User}, %Param );

    # get email addresses of all group members
    my %UserList = $GroupObject->PermissionGroupUserGet(
        GroupID => $Param{User},
        Type    => 'ro',
    );

    my @UserEmails;
    for my $UserID ( sort keys %UserList ) {
         my %UserData = $UserObject->GetUserData(
             UserID => $UserID,
         );

         push @UserEmails, $UserData{UserEmail} if $UserData{UserEmail};
    }

    my $UserEmails = join ', ', @UserEmails;

    return +(
        UserID        => $Param{User},
        UserEmail     => $UserEmails,
        UserFirstname => $LanguageObject->Translate('Members of '),
        UserLastname  => $GroupName,
        UserFullname  => $GroupName,
        UserLogin     => $Param{User},
    );
}

=item Lookup()

=cut

sub Lookup {
    my ($Self, %Param) = @_;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    return $GroupObject->GroupLookup( Group => $Param{UserLogin} );
}


1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

