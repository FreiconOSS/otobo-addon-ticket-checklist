# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ProcessManagement::TransitionAction::AddChecklist;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::ProcessManagement::TransitionAction::Base);

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::Main
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::Priority
    Kernel::Config
);

=head1 NAME

Kernel::System::ProcessManagement::TransitionAction::AddChecklist

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AddChecklistObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::TransitionAction::AddChecklist');

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

    my $AddChecklistResult = $AddChecklistActionObject->Run(
        UserID                   => 123,
        Ticket                   => \%Ticket,   # required
        ProcessEntityID          => 'P123',
        ActivityEntityID         => 'A123',
        TransitionEntityID       => 'T123',
        TransitionActionEntityID => 'TA123',
        Config                   => {
            TemplateID => 123,
        },
    );

Returns:

    $AddChecklistResult = 1; # 0

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $TemplateObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    my $TicketID   = $Param{Ticket}->{TicketID};
    my $TemplateID = $Param{Config}->{TemplateID};

    # get template
    my %Template = $TemplateObject->TemplateGet(
        ID => $TemplateID,
    );

    return 1 if !%Template || !$Template{Items};

    $ChecklistObject->TicketChecklistCreate(
        TicketID  => $TicketID,
        UserID    => $Param{UserID},
    );

    # save items
    my $PosCounter = 1;
    for my $Item ( @{ $Template{Items} } ) {
        my $DueDate;

        if ( $Item->{DueDateDiff} ) {
            $DueDate = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $TimeObject->SystemTime() + ( $Item->{DueDateDiff} * 60 ),
            );
        }

        my $DateStart;

        if ( $Item->{DateStartDiff} ) {
            $DateStart = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $TimeObject->SystemTime() + ( $Item->{DateStartDiff} * 60 ),
            );
        }

        my $StatusID = delete $Item->{Status};

        $ChecklistObject->TicketChecklistAdd(
            %{$Item},
            StatusID      => $StatusID,
            Position      => $PosCounter,
            PriorityID    => $Item->{Priority},
            ResponsibleID => $Item->{Responsible} || $Param{UserID} || 1,
            DueDate       => $DueDate,
            DateStart     => $DateStart,
            TicketID      => $TicketID,
            UserID        => $Param{UserID},
        );

        $PosCounter++;
    }

    my $FieldName = 'TicketChecklistTemplates';
    my $Field     = $DynamicFieldObject->DynamicFieldGet( Name => $FieldName );

    return 1 if !$Field;

    $BackendObject->ValueSet(
        DynamicFieldConfig => $Field,
        ObjectID           => $Param{Ticket}->{TicketID},
        Value              => $TemplateID,
        UserID             => $Param{UserID},
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
