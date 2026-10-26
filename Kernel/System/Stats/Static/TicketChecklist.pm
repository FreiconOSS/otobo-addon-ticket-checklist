# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Stats::Static::TicketChecklist;

use strict;
use warnings;

use Kernel::Language qw(Translatable);


our @ObjectDependencies = qw(
    Kernel::System::Queue
    Kernel::System::State
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub GetObjectBehaviours {
    my ( $Self, %Param ) = @_;

    my %Behaviours = (
        ProvidesDashboardWidget => 0,
    );

    return %Behaviours;
}

sub Param {
    my $Self = shift;

    my $QueueObject    = $Kernel::OM->Get('Kernel::System::Queue');
    my $StateObject    = $Kernel::OM->Get('Kernel::System::State');

    my %QueueList = $QueueObject->GetAllQueues();

    # get state list
    my %StateList = $StateObject->StateList(
        UserID => 1,
    );


    # set params
    my @Params = (
        {
            Frontend   => 'Queue',
            Name       => 'QueueIDs',
            Multiple   => 1,
            Size       => 5,
            Data       => \%QueueList,
        },
        {
            Frontend   => 'State',
            Name       => 'StateIDs',
            Multiple   => 1,
            Size       => 5,
            Data       => \%StateList,
        },
    );

    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $LanguageObject  = $Kernel::OM->Get('Kernel::Language');

    my %Opts;

    NAME:
    for my $Name ( qw(QueueIDs StateIDs) ) {
        next NAME if !defined $Param{$Name};
        next NAME if ref( $Param{$Name} ) && !@{ $Param{$Name} };

        $Opts{$Name} = $Param{$Name};
    }

    # get involved Tickets
    my @TicketIDs = $TicketObject->TicketSearch(
        %Opts,
        Result => 'ARRAY',
        UserID => 1,
    );

    my @Data;

    TICKETID:
    for my $TicketID ( @TicketIDs ) {
        my @ChecklistItems = $ChecklistObject->TicketChecklistTicketGet( TicketID => $TicketID );

        next TICKETID if !@ChecklistItems;

        my %Ticket = $TicketObject->TicketGet( TicketID => $TicketID );

        $Ticket{State} = $LanguageObject->Translate( $Ticket{State} );

        push @Data, [ @Ticket{qw/Title TicketNumber State Queue/} ];

        for my $Item ( @ChecklistItems ) {
            $Item->{Status}  = $LanguageObject->Translate( $Item->{Status} );
            $Item->{DueDate} = $LanguageObject->FormatTimeString(
                $Item->{DueDate},
                'DateFormat',           # which date format to use, e. g. DateFormatLong
            );

            push @Data, [ '', @{$Item}{qw/Title DueDate Responsible Status/} ];
        }
    }

    # table headlines
    my @HeadData = (
        'Title',
        'TicketNumber',
        'State',
        'Queue',
        '',
    );

    @HeadData = map{ $LanguageObject->Translate($_) }@HeadData;

    # set report title
    my $Title = $LanguageObject->Translate( 'Checklists per Ticket' );

    return ( [$Title], [@HeadData], @Data );
}

1;
