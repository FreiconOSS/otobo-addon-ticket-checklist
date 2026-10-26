# --
# Kernel/System/PerlServices/TicketChecklistUtils.pm - Some utility methods for the TicketChecklist addon
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.d
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklistUtils;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::Ticket
    Kernel::System::Queue
    Kernel::System::Group
    Kernel::System::Main
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklistUtils - utility methods for the TicketChecklist addon

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

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $Self->{Debug}   = $ConfigObject->Get('TicketChecklist::Debug');

    return $Self;
}

=item TicketPossibleResponsibles

    my %Users = $Object->TicketPossibleResponsibles(
        TicketID => 1235,
    );

=cut

sub TicketPossibleResponsibles {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # check needed stuff
    for my $Needed ( qw(TicketID Agents) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $QueueID    = $TicketObject->TicketQueueID( TicketID => $Param{TicketID} );
    my $GID        = $QueueObject->GetQueueGroupID( QueueID => $QueueID );
    my %MemberList = $GroupObject->GroupMemberList(
        GroupID => $GID,
        Type    => 'ro',
        Result  => 'HASH',
    );

    if ( $Self->{Debug} ) {
        $LogObject->Log(
            Priority => 'notice',
            Message  => $MainObject->Dump( [ \%Param, $QueueID, $GID, \%MemberList ] ),
        );
    }

    my %ShownUsers;
    for my $MemberKey ( sort keys %MemberList ) {
        if ( $Param{Agents}->{$MemberKey} ) {
            $ShownUsers{$MemberKey} = $Param{Agents}->{$MemberKey};
        }
    }

    return %ShownUsers;
}

=item ReplaceMacros()

This method replaces all the <OTRS_xxxx> macros in notification text.

    my $CleanText = $UtilsObject->ReplaceMacros(
        Text      => 'Some <OTRS_CONFIG_FQDN> text',
        RichText  => 1,           # optional, is Text richtext or not. default 0
        Recipient => {%User},
        Item      => {%ChecklistItemData},
        Ticket    => {%Ticket},
        Language  => $Language,    # used for translating states and such
        UserID    => 1,
    );

=cut

sub ReplaceMacros {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

    # check needed stuff
    for my $Needed (qw(Text Item UserID Ticket Language)) {
        if ( !defined $Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Text = $Param{Text};

    # determine what "macro" delimiters are used
    my $Start = '<';
    my $End   = '>';

    # with richtext enabled, the delimiters change
    if ( $Param{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Text =~ s{ (\n|\r) }{}xmsg;
    }

    my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
    my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';
    my $AutocompleteObject = $Kernel::OM->Get(
        'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
    );

    # translate Change and Workorder values, where appropriate
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::Language' => {
            UserLanguage => $Param{Language},
        },
    );
    my $LanguageObject = $Kernel::OM->Get('Kernel::Language');

    my %ItemData = %{ $Param{Item} };
    for my $Field (qw(Notification Priority)) {
        $ItemData{$Field} = $LanguageObject->Translate( $ItemData{$Field} );
    }

    my %TicketData = %{ $Param{Ticket} };
    for my $Field (qw(State Priority)) {
        $TicketData{$Field} = $LanguageObject->Translate( $TicketData{$Field} );
    }

    # replace config options
    my $Tag = $Start . 'OTRS_CONFIG_';
    $Text =~ s{ $Tag (.+?) $End }{$ConfigObject->Get($1)}egx;

    # cleanup
    $Text =~ s{ $Tag .+? $End }{-}gi;

    $Tag = $Start . 'OTRS_Agent_';
    my $Tag2 = $Start . 'OTRS_CURRENT_';
    my %CurrentUser = $UserObject->GetUserData( UserID => $Param{UserID} );

    # html quoting of content
    if ( $Param{RichText} ) {
        KEY:
        for my $Key ( sort keys %CurrentUser ) {
            next KEY if !$CurrentUser{$Key};
            $CurrentUser{$Key} = $HTMLUtilsObject->ToHTML(
                String => $CurrentUser{$Key},
            );
        }
    }

    # replace it
    KEY:
    for my $Key ( sort keys %CurrentUser ) {
        next KEY if !defined $CurrentUser{$Key};
        $Text =~ s{ $Tag $Key $End }{$CurrentUser{$Key}}gxmsi;
        $Text =~ s{ $Tag2 $Key $End }{$CurrentUser{$Key}}gxmsi;
    }

    # replace other needed stuff
    $Text =~ s{ $Start OTRS_FIRST_NAME $End }{$CurrentUser{UserFirstname}}gxms;
    $Text =~ s{ $Start OTRS_LAST_NAME $End }{$CurrentUser{UserLastname}}gxms;

    # cleanup
    $Text =~ s{ $Tag .+? $End}{-}xmsgi;
    $Text =~ s{ $Tag2 .+? $End}{-}xmsgi;

    # replace <OTRS_CHECKLISTITEM_... tags
    {
        my $Tag = $Start . 'OTRS_CHECKLISTITEM_';

        # html quoting of content
        if ( $Param{RichText} ) {
            KEY:
            for my $Key ( sort keys %ItemData ) {
                next KEY if !$ItemData{$Key};
                $ItemData{$Key} = $HTMLUtilsObject->ToHTML(
                    String => $ItemData{$Key},
                );
            }
        }

        # get user data
        my %UserData;
        if ( $UseAutocomplete ) {
            %UserData = $AutocompleteObject->GetUserData(
                User => $ItemData{ResponsibleKey},
            );
        }
        else {
            %UserData = $UserObject->GetUserData(
                UserID => $ItemData{ResponsibleID},
                Valid  => 1,
            );
        }

        if ( !%UserData ) {
            %UserData = ( UserFirstname => '', UserLastname => '' );
        }

        # build user attribute
        $UserData{UserFirstname} //= '';
        $UserData{UserLastname}  //= '';
        $ItemData{User} = "$UserData{UserFirstname} $UserData{UserLastname}";

        # replace it
        KEY:
        for my $Key ( sort keys %ItemData ) {
            next KEY if !defined $ItemData{$Key};
            $Text =~ s{ $Tag $Key $End }{$ItemData{$Key}}gxmsi;
        }

        # cleanup
        $Text =~ s{ $Tag .+? $End}{-}gxmsi;
    }

    # replace <OTRS_TICKET_... tags
    {
        my $Tag = $Start . 'OTRS_TICKET_';

        # html quoting of content
        if ( $Param{RichText} ) {
            KEY: 
            for my $Key ( sort keys %TicketData ) {
                next KEY if !$TicketData{$Key};
                $TicketData{$Key} = $HTMLUtilsObject->ToHTML(
                    String => $TicketData{$Key},
                );
            }
        }

        # replace it
        KEY: 
        for my $Key ( sort keys %TicketData ) {
            next KEY if !defined $TicketData{$Key};
            $Text =~ s{ $Tag $Key $End }{$TicketData{$Key}}gxmsi;
        }

        # cleanup
        $Text =~ s{ $Tag .+? $End}{-}gxmsi;
    }

    # replace generic text
    {
        my $GenericText = $Param{GenericText} // '-';
        $Text =~ s{$Start OTRS_CHECKLIST_VARIABLETEXT $End}{$GenericText}xgms;
    }

    # get recipient data and replace it with <OTRS_...
    $Tag = $Start . 'OTRS_';
    if ( $Param{Recipient} ) {

        # html quoting of content
        if ( $Param{RichText} ) {
            KEY:
            for my $Key ( sort keys %{ $Param{Recipient} } ) {
                next KEY if !$Param{Recipient}->{$Key};
                $Param{Recipient}->{$Key} = $HTMLUtilsObject->ToHTML(
                    String => $Param{Recipient}->{$Key},
                );
            }
        }

        # replace it
        KEY:
        for my $Key ( sort keys %{ $Param{Recipient} } ) {
            next KEY if !defined $Param{Recipient}->{$Key};
            my $Value = $Param{Recipient}->{$Key};
            $Text =~ s{ $Tag $Key $End }{$Value}gxmsi;
        }
    }

    # cleanup
    $Text =~ s{ $Tag .+? $End}{-}gxmsi;

    return $Text;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

