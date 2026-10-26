# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::ConditionAction::ChangeChecklistItems;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::Main
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::Priority
    Kernel::Config
);

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ChangeChecklistItemsObject = $Kernel::OM->Get('Kernel::System::PerlServices::ConditionAction::ChangeChecklistItems');

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

    my $ChangeChecklistItemsResult = $ChangeChecklistItemsActionObject->Run(
        UserID                   => 123,
        TicketID                 => 123,
        ItemID                   => 133,
        Params                   => {
            Item_1        => 'Name of Checklist item',
            Responsible_1 => 'New responsible for item 1',
            Item_2        => 'Name of second Checklist item',
            DueDate_2     => '2016-10-18 12:11:00',
            Status_2      => 'done',
        },
    );

Returns:

    $ChangeChecklistItemsResult = 1; # 0

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $PriorityObject  = $Kernel::OM->Get('Kernel::System::Priority');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');

    my $TicketID = $Param{TicketID};

    my %ItemChanges;
    my @ItemNameParams = grep{ $_ =~ m{\AItem_\d+} }keys %{ $Param{Params} || {} };

    my $UseAutocomplete = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete');
    my $Module          = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule');

    my $ResponsibleObject = $Kernel::OM->Get('Kernel::System::User');
    my $Method            = 'UserLookup';

    if ( $UseAutocomplete ) {
        $ResponsibleObject = $Kernel::OM->Get(
            'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $Module
        );

        $Method = 'Lookup';
    }

    for my $NameParam ( @ItemNameParams ) {
        my ($Count) = $NameParam =~ m{\AItem_ (\d+) \z}xms;

        my $Name = $Param{Params}->{$NameParam};

        KEY:
        for my $Key ( qw/Status DueDate Responsible Priority/ ) {
            my $Value = $Param{Params}->{ $Key . '_' . $Count };

            next KEY if !defined $Value || $Value eq '';

            $ItemChanges{$Name}->{$Key} = $Value;
        }

        if ( $ItemChanges{$Name}->{Priority} ) {
            $ItemChanges{$Name}->{PriorityID} = $PriorityObject->PriorityLookup(
                Priority => $ItemChanges{$Name}->{Priority},
            );
        }

        if ( $ItemChanges{$Name}->{Responsible} ) {
            my $ResponsibleKey = $UseAutocomplete ? 'ResponsibleKey' : 'ResponsibleID';

            $ItemChanges{$Name}->{$ResponsibleKey} = $ResponsibleObject->$Method(
                UserLogin => $ItemChanges{$Name}->{Responsible},
            );
        }
    }

    # update checklist items
    NAME:
    for my $Name ( sort keys %ItemChanges ) {
        my $ID = $ChecklistObject->ChecklistItemLookup(
            Name     => $Name,
            TicketID => $TicketID,
        );

        next NAME if !$ID;

        my %Item = $ChecklistObject->TicketChecklistGet(
            ID => $ID,
        );

        $ChecklistObject->TicketChecklistUpdate(
            %Item,
            %{ $ItemChanges{$Name} },
            UserID         => $Param{UserID},
            WorkflowUserID => 0,
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
