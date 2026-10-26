# --
# Kernel/System/PerlServices/TicketChecklist/Autocomplete/Agent.pm - Agent backend for responsible autocomplete
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Autocomplete::Agent;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::User
    Kernel::System::Valid
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklist::Autocomplete::Agent - backend for responsible autocomplete

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

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

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

    my %Users = $UserObject->UserSearch(
        Search => $Param{Term} . '*',
    );

    my %PossibleResponsibles;
    for my $UserID ( keys %Users ) {
        my %UserData = $UserObject->GetUserData(
            UserID => $UserID,
        );

        $PossibleResponsibles{$UserID} = \%UserData;
    }

    return \%PossibleResponsibles;
}

=item MemberOfList()

=cut

sub MemberOfList {
    my ( $Self, %Param ) = @_;

    return $Param{UserID};
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

    return '' if !$Param{UserLogin};

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    return $UserObject->UserName( UserID => $Param{UserLogin}, %Param );
}

=item GetUserData()

=cut

sub GetUserData {
    my ($Self, %Param) = @_;

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    return $UserObject->GetUserData(
        UserID => $Param{User},
    );
}

=item Lookup()

=cut

sub Lookup {
    my ($Self, %Param) = @_;

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    return $UserObject->UserLookup( UserLogin => $Param{UserLogin} );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

