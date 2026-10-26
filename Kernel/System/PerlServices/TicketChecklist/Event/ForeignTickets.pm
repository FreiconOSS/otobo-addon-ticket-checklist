# --
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::ForeignTickets;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::Ticket
    Kernel::System::User
    Kernel::System::Log
    Kernel::Config
);

=head1 NAME

Kernel::System::PerlServices::Event::ForeignTickets - HandleForeignTickets

=head1 SYNOPSIS

Event handler module for change notes in ticket checklist

=head1 PUBLIC INTERFACE

=over 4

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

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $LanguageObject  = $Kernel::OM->Get('Kernel::Language');

    # check needed stuff
    for my $Argument (qw(Data Event Config UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # do not modify the original event, because we need this unmodified in later event modules
    my $Event = $Param{Event};

    my %Item = $ChecklistObject->TicketChecklistGet(
        ID => $Param{Data}->{ItemID},
    );

    return 1 if !$Item{ForeignTicketID};

    if ( $Event eq 'ItemChangeNote' ) {

        return 1 if !$ConfigObject->Get('TicketChecklist::ChangeNoteAsFollowUpForeignTicket');

        my $From    = $UserObject->UserName( UserID => $Param{UserID} ) // 'OTRS';
        my $Subject = $LanguageObject->Translate('Note');

        my $ArticleID = $Kernel::OM->Get('Kernel::System::Ticket::Article::Backend::Internal')->ArticleCreate(
            TicketID             => $Item{ForeignTicketID},
            IsVisibleForCustomer => 0,
            SenderType           => 'system',
            From                 => $From,
            Subject              => $Subject,
            Body                 => $Param{Data}->{ChangeNote},
            ContentType          => 'text/plain; utf-8',
            HistoryType          => 'AddNote',
            HistoryComment       => '%%',
            UserID               => $Param{UserID},
        );
    }

    elsif ( $Event eq 'ItemStatusUpdate' ) {
        my $Mapping  = $ConfigObject->Get('TicketChecklist::ItemStateToTicketState') || {};
        my $NewState = $Mapping->{ $Item{Status} } || 'open';

        $TicketObject->TicketStateSet(
            TicketID => $Item{ForeignTicketID},
            State    => $NewState,
            UserID   => $Param{UserID},
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
