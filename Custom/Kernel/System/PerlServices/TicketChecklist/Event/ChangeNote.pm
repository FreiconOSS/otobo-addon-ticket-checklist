# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::ChangeNote;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistNotification
    Kernel::System::Ticket
    Kernel::System::User
    Kernel::System::Log
    Kernel::Config
);

=head1 NAME

Kernel::System::PerlServices::Event::ChangeNote - TicketChecklist notification lib

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

    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $NotificationObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistNotification');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');

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

    return 1 if !defined $Param{Data}->{ChangeNote};

    my %Item = $ChecklistObject->TicketChecklistGet(
        ID => $Param{Data}->{ItemID},
    );

    # add change note to article
    my $ShallCreateArticle = $ConfigObject->Get('TicketChecklist::ChangeNoteAsArticle');
    if ( $ShallCreateArticle ) {
        my $ArticleConfig = $ConfigObject->Get('TicketChecklist::ChangeNoteArticle') || {};
        my $ArticleType   = $ArticleConfig->{Type}    || 'note-internal';
        my $Subject       = $ArticleConfig->{Subject} || 'TODO item changed';
        my $From          = $UserObject->UserName( UserID => $Param{UserID} ) // 'OTRS';

        if ( $Subject =~ m{<OTRS_CHECKLISTITEM_}xms ) {
            my $Tag = '<OTRS_CHECKLISTITEM_';

            # get user data
            my %UserData;
            if ( $Subject =~ m{$Tag User>}xms ) {
                my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
                my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';
                my $AutocompleteObject = $Kernel::OM->Get(
                    'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
                );

                if ( $UseAutocomplete ) {
                    %UserData = $AutocompleteObject->GetUserData(
                        User => $Item{ResponsibleKey},
                    );
                }
                else {
                    %UserData = $UserObject->GetUserData(
                        UserID => $Item{ResponsibleID},
                        Valid  => 1,
                    );
                }
            }

            if ( !%UserData ) {
                %UserData = ( UserFirstname => '', UserLastname => '' );
            }

            # build user attribute
            $Item{User} = "$UserData{UserFirstname} $UserData{UserLastname}";

            # replace it
            KEY:
            for my $Key ( sort keys %Item ) {
                next KEY if !defined $Item{$Key};
                $Subject =~ s{ $Tag $Key > }{$Item{$Key}}gxmsi;
            }

            $Subject =~ s{ $Tag .+? >}{-}gxmsi;
        }


        my $ArticleID = $Kernel::OM->Get('Kernel::System::Ticket::Article::Backend::Internal')->ArticleCreate(
            TicketID             => $Param{Data}->{TicketID},
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

    # send change note notification
    my $ShallSendNotification = $ConfigObject->Get('TicketChecklist::ChangeNoteAsNotification');
    return 1 if !$ShallSendNotification;

    my $IsOwnAction = 0;

    my %UserData = $UserObject->GetUserData( UserID => $Param{UserID} );

    my $IsResponsible =
        $Item{ResponsibleID} == $Param{UserID} ||
        $Item{ResponsibleKey} eq $UserData{UserLogin} ||
        $Item{ResponsibleKey} eq $Param{UserID};


    if ( $IsResponsible ) {
        $IsOwnAction = 1;
    }

    return 1 if $IsOwnAction;

    $NotificationObject->NotificationSend(
        %Param,
        Data        => \%Item,
        AgentIDs    => [ $Item{ResponsibleKey} || $Item{ResponsibleID} ],
        GenericText => $Param{Data}->{ChangeNote},
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
