# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::ConditionAction::TicketSetDynamicField;

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
    Kernel::System::Ticket
    Kernel::System::User
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

    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject         = $Kernel::OM->Get('Kernel::System::Main');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $UtilsObject        = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistUtils');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');

    my $TicketID = $Param{TicketID};

    for my $FieldName ( keys %{ $Param{Params} || {} } ) {
        my $Field = $DynamicFieldObject->DynamicFieldGet( Name => $FieldName );
        my $Value = $Param{Params}->{$FieldName};

        if ( $Value =~ m{<OTRS_} ) {
            my %ChecklistItemData = $ChecklistObject->TicketChecklistGet(
                ID => $Param{ItemID},
            );

            my %Ticket = $TicketObject->TicketGet(
                TicketID => $TicketID,
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

        $BackendObject->ValueSet(
            DynamicFieldConfig => $Field,
            ObjectID           => $TicketID,
            Value              => $Value,
            UserID             => $Param{UserID},
        );
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
