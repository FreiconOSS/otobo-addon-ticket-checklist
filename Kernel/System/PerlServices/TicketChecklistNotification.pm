# --
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-29: a missing notification text is logged as debug, not as error.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklistNotification;

use strict;
use warnings;

use Kernel::System::ObjectManager;
use Kernel::System::EventHandler;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Cache
    Kernel::System::Email
    Kernel::System::HTMLUtils
    Kernel::System::Notification
    Kernel::System::Valid
    Kernel::Language
    Kernel::System::PerlServices::TicketChecklistUtils
);

use vars qw(@ISA);

@ISA = (
    'Kernel::System::EventHandler',
);

=head1 NAME

Kernel::System::PerlServices::TicketChecklistNotification - ...

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

    # set the debug flag
    $Self->{Debug} = $Param{Debug} || 0;

    # create additional objects
    $Self->{Cache} = {
        Type => 'TicketChecklist',
        TTL  => 3600,
    };

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # do we use richtext
    $Self->{RichText} = $ConfigObject->Get('Frontend::RichText');

    # set up empty cache for _NotificationGet()
    $Self->{NotificationCache} = {};

    # init of event handler
    $Self->EventHandlerInit(
        Config     => 'TicketChecklistNotification::EventModule',
    );

    return $Self;
}

=item NotificationAdd()

Add status

    my $ID = $NotificationObject->NotificationAdd(
        Event       => 'ItemDelete',
        Language    => 'de',
        Subject     => 'testsubject',
        Text        => 'A text'.
        ContentType => 'text/plain',
        ValidID     => 123,
        UserID      => 123,
    );

=cut

sub NotificationAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    for my $Needed (qw(Event Language Subject Text ContentType UserID ValidID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $CheckID = $Self->NotificationLookup(
        Event    => $Param{Event},
        Language => $Param{Language},
    );

    if ( $CheckID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "notification alread exists",
        );

        return;
    }

    # insert state
    return if !$DBObject->Do(
        SQL => 'INSERT INTO ps_checklist_notify '
            . '(notification_type, language, subject, notification_text, content_type,'
            . 'create_time, create_by, change_time, change_by, valid_id)'
            . 'VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?, ?)',
        Bind => [
            \$Param{Event},
            \$Param{Language},
            \$Param{Subject},
            \$Param{Text},
            \$Param{ContentType},
            \$Param{UserID},
            \$Param{UserID},
            \$Param{ValidID},
        ],
    );

    my $ID = $Self->NotificationLookup(
        Event    => $Param{Event},
        Language => $Param{Language},
    );

    # log notice
    $LogObject->Log(
        Priority => 'notice',
        Message  => "Notification '$ID' created successfully ($Param{UserID})!",
    );

    return $ID;
}


=item NotificationUpdate()

to update notification 

    my $Success = $NotificationObject->NotificationUpdate(
        ID            => 3,
        Event         => 1984756823,
        Language      => 1984756823,
        ContentType   => '',
        Subject       => 1,
        Text          => 1,
        ValidID       => 123,
        UserID        => 123,
    );

=cut

sub NotificationUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    for my $Needed (qw(ID Event Language Subject Text ContentType UserID ValidID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $CheckID = $Self->NotificationLookup(
        Event    => $Param{Event},
        Language => $Param{Language},
    );

    if ( $CheckID && $CheckID != $Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "notification alread exists",
        );
    }

    # update state
    return if !$DBObject->Do(
        SQL => 'UPDATE ps_checklist_notify SET '
            . ' notification_type = ?, language = ?, subject = ?, notification_text = ?, '
            . ' content_type = ?, change_time = current_timestamp, change_by = ?, valid_id = ?'
            . ' WHERE id = ?',
        Bind => [
            \$Param{Event},
            \$Param{Language},
            \$Param{Subject},
            \$Param{Text},
            \$Param{ContentType},
            \$Param{UserID},
            \$Param{ValidID},
            \$Param{ID},
        ],
    );

    return 1;
}

=item NotificationGet()

returns a hash with status data

    my %NotificationData = $NotificationObject->NotificationGet( ID => 2 );

This returns something like:

    %NotificationData = (
        ID          => 3,
        Event       => 'ItemDelete',
        Text        => 'A Text',
        Language    => 'de',
        ValidID     => 123,
        Subject     => 'Test subject',
        ContentType => 'text/plain',
        CreateBy    => 354,
        CreateTime  => '',
        ChangeBy    => 35,
        ChangeTime  => '',
    );

=cut

sub NotificationGet {
    my ( $Self, %Param ) = @_;

    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');

    # check needed stuff
    if ( !$Param{ID} && ( !$Param{Event} || !$Param{Language} ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need either ID or Event and Language!',
        );
        return;
    }

    # sql
    my $SQL = qq~
        SELECT
            id, notification_type, language, subject, notification_text, content_type,
            create_by, create_time, change_by, change_time, valid_id
        FROM ps_checklist_notify
        WHERE id = ?
    ~;
    my @Bind = ( \$Param{ID} );

    if ( $Param{Event} && $Param{Language} ) {
        $SQL = qq~
            SELECT
                id, notification_type, language, subject, notification_text, content_type,
                create_by, create_time, change_by, change_time, valid_id
            FROM ps_checklist_notify
            WHERE notification_type = ? AND language = ?
        ~;
        @Bind = ( \$Param{Event}, \$Param{Language} );
    }

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    my %Notification;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Notification = (
            ID          => $Data[0],
            Event       => $Data[1],
            Language    => $Data[2],
            Subject     => $Data[3],
            Text        => $Data[4],
            ContentType => $Data[5],
            CreateBy    => $Data[6],
            CreateTime  => $Data[7],
            ChangeBy    => $Data[8],
            ChangeTime  => $Data[9],
            ValidID     => $Data[10],
        );
    }

    return if !%Notification;

    $Notification{Creator} = $UserObject->UserLookup( UserID => $Notification{CreateBy} );

    return %Notification;
}

=item NotificationDelete()

deletes a notification. Returns 1 if it was successful, undef otherwise.

    my $Success = $NotificationObject->NotificationDelete(
        ID => 123,
    );

=cut

sub NotificationDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need ID!',
        );
        return;
    }

    return $DBObject->Do(
        SQL  => 'DELETE FROM ps_checklist_notify WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
}

=item NotificationList()

=cut

sub NotificationList {
    my ($Self, %Param) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = 'SELECT id, language, notification_type FROM ps_checklist_notify';

    if ( $Param{Valid} && $Param{Valid} == 1 ) {
        $SQL .= ' WHERE valid_id = 1';
    }

    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    my %NotificationList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $NotificationList{ $Row[0] } = $Row[1] . '::' . $Row[2];
    }

    return %NotificationList;
}

=item NotificationLookup()

    my $Name = $NotificationObject->NotificationLookup(
        ID => 123,
    );

or

    my $ID = $NotificationObject->NotificationLookup(
        Event    => 'ItemDelete',
        Language => 'de',
    );

=cut

sub NotificationLookup {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{ID} && ( !$Param{Event} || !$Param{Language} ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need either ID or Event and Language!',
        );
        return;
    }

    my $SQL  = 'SELECT id FROM ps_checklist_notify WHERE notification_type = ? AND language = ?';
    my $Bind = [ \$Param{Event}, \$Param{Language} ];

    if ( $Param{ID} ) {
        $SQL  = 'SELECT language, notification_type FROM ps_checklist_notify WHERE id = ?';
        $Bind = [ \$Param{ID} ];
    }

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => $Bind,
        Limit => 1,
    );

    my $Value;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Value = $Row[0];

        $Value .= '::' . $Row[1] if $Row[1];
    }

    return $Value;
}

=item NotificationSend()

Send the notification to agents.

    my $Success = $NotificationObject->NotificationSend(
        AgentIDs    => [ 1, 2, 3, ]
        Event       => 'ItemNotificationUpdate',
        Data        => { %ChecklisteItemData },
        GenericText => 'test',
        UserID      => 123,
    );

=cut

sub NotificationSend {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $ValidObject     = $Kernel::OM->Get('Kernel::System::Valid');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
    my $JSONObject      = $Kernel::OM->Get('Kernel::System::JSON');
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $SendmailObject  = $Kernel::OM->Get('Kernel::System::Email');
    my $UtilsObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistUtils');

    # check needed stuff
    for my $Argument (qw(Event UserID Data AgentIDs)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # for convenience
    my $Event = $Param{Event};

    # AgentIDs has to be an array reference
    for my $IDKey (qw(AgentIDs)) {
        if ( defined $Param{$IDKey} && ref $Param{$IDKey} ne 'ARRAY' ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "$IDKey has to be an array reference!",
            );
            return;
        }
    }

    # get the valid ids
    my @ValidIDs = $ValidObject->ValidIDsGet();
    my %ValidIDLookup = map { $_ => 1 } @ValidIDs;

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Param{UserID},
    );

    my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete') ? 1 : 0;
    my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

    my %AgentsSent;

    AGENTID:
    for my $AgentID ( @{ $Param{AgentIDs} } ) {

        # check if notification was already sent to this agent
        next AGENTID if !$AgentID;
        next AGENTID if $AgentsSent{$AgentID};

        my %User;

        # if autocomplete feature is active, get user data from autocomplete module
        if ( $UseAutocomplete ) {
            my $AutocompleteObject = $Kernel::OM->Get(
               'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
            );

            %User = $AutocompleteObject->GetUserData(
                User => $AgentID,
            );
        }

        # User info for prefered language and macro replacement
        if ( !%User ) {
            %User = $UserObject->GetUserData(
                UserID => $AgentID,
            );
        }

        # do not send emails to invalid agents
        if ( exists $User{ValidID} && !$ValidIDLookup{ $User{ValidID} } ) {
            next AGENTID;
        }

        if ( !$User{UserEmail} ) {
            $LogObject->Log(
                Priority => 'notice',
                Message  => "Cannot send notification to $AutocompleteModule $AgentID: It does not have an email",
            );

            next AGENTID;
        }

        my %Preferences = $UserObject->GetPreferences( UserID => $AgentID );

        # check if user is unsubscribed
        my $PreferNotifications = $Preferences{ChecklistNotifications} || '{}';
        my $Event               = $Param{Event};
        my $DecodedPreferences  = $JSONObject->Decode( Data => $PreferNotifications );
        if ( defined $DecodedPreferences->{$Event} && !$DecodedPreferences->{$Event} ) {
            next AGENTID;
        }

        my $PreferredLanguage = $Preferences{UserLanguage} || $ConfigObject->Get('DefaultLanguage') || 'en';

        # get notification (cache || database)
        my $Notification = $Self->_NotificationGet(
            Event    => $Param{Event},
            Language => $PreferredLanguage,
        );

        return if !$Notification;

        # replace otrs macros
        $Notification->{Text} = $UtilsObject->ReplaceMacros(
            Text        => $Notification->{Text},
            Recipient   => {%User},
            RichText    => $Self->{RichText},
            UserID      => $Param{UserID},
            Ticket      => \%Ticket,
            Item        => $Param{Data},
            Language    => $PreferredLanguage,
            GenericText => $Param{GenericText},
        );

        $Notification->{Subject} = $UtilsObject->ReplaceMacros(
            Text        => $Notification->{Subject},
            Recipient   => {%User},
            UserID      => $Param{UserID},
            Ticket      => \%Ticket,
            Item        => $Param{Data},
            Language    => $PreferredLanguage,
            GenericText => $Param{GenericText},
        );

        # add urls and verify to be full html document
        if ( $Self->{RichText} ) {

            $Notification->{Text} = $HTMLUtilsObject->LinkQuote(
                String => $Notification->{Text},
            );

            $Notification->{Text} = $HTMLUtilsObject->DocumentComplete(
                Charset => 'utf-8',
                String  => $Notification->{Text},
            );
        }

        # send notification
        $SendmailObject->Send(
            From => $ConfigObject->Get('NotificationSenderName') . ' <'
                . $ConfigObject->Get('NotificationSenderEmail') . '>',
            To       => $User{UserEmail},
            Subject  => $Notification->{Subject},
            MimeType => $Notification->{ContentType} || 'text/plain',
            Charset  => 'utf-8',
            Body     => $Notification->{Text},
            Loop     => 1,
        );

        # trigger NotificationSent-Event
        $Self->EventHandler(
            Event => 'TicketChecklistNotificationSentPost',
            Data  => {
                ItemID    => $Param{Data}->{ID},
                EventType => $Event,
                To        => $User{UserEmail},
            },
            UserID => $Param{UserID},
        );

        $AgentsSent{$AgentID} = 1;
    }

    return 1;
}

=begin Internal:

=item _NotificationGet()

Get the notification template from cache or from the NotificationObject.
Also convert to notification the appropriate content type.

    my $Notification = $NotificationObject->_NotificationGet(
        NotificationKey => 'en::Agent::WorkOrder::WorkOrderUpdate',
    );

=cut

sub _NotificationGet {
    my ( $Self, %Param ) = @_;

    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $HTMLUtilsObject    = $Kernel::OM->Get('Kernel::System::HTMLUtils');

    # check needed stuff
    for my $Argument (qw(Event Language)) {
        if ( !defined $Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get from database
    my %NotificationData = $Self->NotificationGet(
        Event    => $Param{Event},
        Language => $Param{Language},
    );

    # no notification found - not an error: only the events and languages an
    # administrator has set up in AdminTicketChecklistNotifications send one
    if ( !%NotificationData ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => "Could not find notification for $Param{Event} ($Param{Language})",
        );

        return;
    }

    if ( $NotificationData{ValidID} != 1 ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => "Notification is invalid",
        );

        return;
    }

    # do text/plain to text/html convert
    if ( $Self->{RichText} && $NotificationData{ContentType} =~ m{ text/plain }xmsi ) {
        $NotificationData{ContentType} = 'text/html';
        $NotificationData{Text}        = $HTMLUtilsObject->ToHTML(
            String => $NotificationData{Text},
        );
    }

    # do text/html to text/plain convert
    elsif ( !$Self->{RichText} && $NotificationData{ContentType} =~ m{ text/html }xmsi ) {
        $NotificationData{ContentType} = 'text/plain';
        $NotificationData{Text}        = $HTMLUtilsObject->ToAscii(
            String => $NotificationData{Text},
        );
    }

    # return data
    return \%NotificationData;
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
