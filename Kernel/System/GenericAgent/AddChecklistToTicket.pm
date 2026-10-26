# --
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::GenericAgent::AddChecklistToTicket;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::DateTime
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
    Kernel::System::PerlServices::TicketChecklistTemplate
    Kernel::System::PerlServices::TicketChecklist
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $TemplateObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    $Param{TemplateID} ||= $Param{New}->{TemplateID};
    $Param{UserID}     ||= $Param{New}->{UserID};

    for my $Needed ( qw/TicketID UserID TemplateID/ ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    # get template
    my %Template = $TemplateObject->TemplateGet(
        ID => $Param{TemplateID},
    );

    return 1 if !%Template || !$Template{Items};

    my @TicketItems = $ChecklistObject->TicketChecklistTicketGet(
        TicketID => $Param{TicketID},
    );

    # save items
    my $PosCounter = 1;
    for my $Item ( @{ $Template{Items} } ) {
        my $DueDate;

        if ( $Item->{DueDateDiff} ) {
            my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
            $DateTimeObject->Add( Seconds => $Item->{DueDateDiff} * 60 );
            $DueDate = $DateTimeObject->ToString();
        }

        my $DateStart;

        if ( $Item->{DateStartDiff} ) {
            my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
            $DateTimeObject->Add( Seconds => $Item->{DateStartDiff} * 60 );
            $DateStart = $DateTimeObject->ToString();
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
            TicketID      => $Param{TicketID},
            UserID        => $Param{UserID},
        );

        $PosCounter++;
    }

    if ( !@TicketItems && $PosCounter > 1 ) {
        $ChecklistObject->TicketChecklistCreate(
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );
    }

    my $FieldName = 'TicketChecklistTemplates';
    my $Field     = $DynamicFieldObject->DynamicFieldGet( Name => $FieldName );
    
    return 1 if !$Field;

    $BackendObject->ValueSet(
        DynamicFieldConfig => $Field,
        ObjectID           => $Param{TicketID},
        Value              => $Param{TemplateID},
        UserID             => $Param{UserID},
    );

    return 1;
}

1;
