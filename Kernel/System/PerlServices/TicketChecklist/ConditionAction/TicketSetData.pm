# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::ConditionAction::TicketSetData;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::Main
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
    Kernel::System::Priority
    Kernel::System::User
    Kernel::System::Ticket
    Kernel::Config
    Kernel::System::PerlServices::TicketChecklistUtils
    Kernel::System::PerlServices::TicketChecklist
);

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketSetDynamicFieldObject = $Kernel::OM->Get('Kernel::System::PerlServices::ConditionAction::TicketSetDynamicField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

Run Data

    my $TicketSetDynamicFieldResult = $TicketSetDynamicFieldActionObject->Run(
        UserID                   => 123,
        TicketID                 => 123,
        ItemID                   => 133,
        Params                   => {
            FieldName1 => 'Value1',
            FieldName2 => 'Value2',
        },
    );

Returns:

    $TicketSetDynamicFieldResult = 1; # 0

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
    my $UtilsObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistUtils');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');

    my @PlainMethods = qw(Queue Type Service SLA Lock ArchiveFlag State Priority);

    my %Mapping = map {
        $_ => $_;
    } @PlainMethods;

    $Mapping{Owner}       = 'NewUserID';
    $Mapping{Responsible} = 'NewUserID';
    $Mapping{Customer}    = 'User';

    my %Args = (
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    my $Field = $Param{Params}->{Field};
    my $Value = $Param{Params}->{Value};

    return if !$Mapping{$Field};

    my $Sub = $TicketObject->can( 'Ticket' . $Field . 'Set' );

    return if !$Sub;

    if ( $Value =~ m{<OTRS_} ) {
        my %ChecklistItemData = $ChecklistObject->TicketChecklistGet(
            ID => $Param{ItemID},
        );

        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
        );

        my %User = $UserObject->GetUserData(
            UserID => $Param{UserID},
        );

        $Value = $UtilsObject->ReplaceMacros(
            Text      => $Value,
            Recipient => {%User},
            Item      => {%ChecklistItemData},
            Ticket    => {%Ticket},
            Language  => 'en',    # used for translating states and such
            UserID    => $Param{UserID},
        );

    }

    my $Key     = $Mapping{$Field};
    $Args{$Key} = $Value;

    $TicketObject->$Sub(
        %Args,
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
