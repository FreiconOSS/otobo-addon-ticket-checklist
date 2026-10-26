# --
# Copyright (C) Freicon GmbH & Co. KG, https://freicon.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

# Covers what broke between 10.1.3 and OTOBO 11: the time handling that ran on the
# removed Kernel::System::Time, the foreign key on the renamed groups table, and
# the ticket PDF with the checklist.

use strict;
use warnings;
use utf8;

# Set up the test driver $Self when we are running as a standalone script.
use Kernel::System::UnitTest::RegisterDriver;
use Kernel::System::UnitTest::MockTime qw(FixedTimeSet);

our $Self;

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
    'Kernel::Output::HTML::Layout' => {
        UserID       => 1,
        Lang         => 'en',
        UserTimeZone => 'Europe/Berlin',
    },
);
my $HelperObject    = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
my $DBObject        = $Kernel::OM->Get('Kernel::System::DB');
my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

$ConfigObject->Set(
    Key   => 'OTOBOTimeZone',
    Value => 'UTC',
);

# freeze the clock, every time stamp below is relative to it
FixedTimeSet(
    $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => { String => '2026-01-15 10:00:00' },
    ),
);

# a time stamp N minutes from the frozen "now", in OTOBO time
my $Minutes = sub {
    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
    $DateTimeObject->Add( Minutes => shift );
    return $DateTimeObject->ToString();
};

# ---------------------------------------------------------------------------
# foreign key of the template/group table points at groups_table
# ---------------------------------------------------------------------------

if ( $DBObject->GetDatabaseFunction('Type') eq 'mysql' ) {
    $DBObject->Prepare(
        SQL => 'SELECT referenced_table_name FROM information_schema.referential_constraints '
            . 'WHERE constraint_schema = DATABASE() AND table_name = ? AND constraint_name = ?',
        Bind => [ \'ps_checklist_tmpl_grp', \'FK_ps_checklist_tmpl_grp_group_id_id' ],
    );
    my $ForeignTable;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ForeignTable = $Row[0];
    }
    $Self->Is( $ForeignTable, 'groups_table', 'group foreign key of ps_checklist_tmpl_grp exists' );
}

# ---------------------------------------------------------------------------
# a ticket with two articles and four checklist items
# ---------------------------------------------------------------------------

my $TicketID = $TicketObject->TicketCreate(
    Title        => 'TicketChecklist unit test',
    Queue        => 'Raw',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    CustomerID   => 'unittest',
    CustomerUser => 'unittest@example.com',
    OwnerID      => 1,
    UserID       => 1,
);
$Self->True( $TicketID, 'ticket created' );

my $ArticleBackendObject = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel(
    ChannelName => 'Internal',
);
my @ArticleIDs;
for my $Number ( 1 .. 2 ) {
    push @ArticleIDs, $ArticleBackendObject->ArticleCreate(
        TicketID             => $TicketID,
        IsVisibleForCustomer => 0,
        SenderType           => 'agent',
        Subject              => "article $Number",
        Body                 => "body $Number",
        ContentType          => 'text/plain; charset=utf8',
        HistoryType          => 'AddNote',
        HistoryComment       => 'unit test',
        UserID               => 1,
    );
}
$Self->Is( scalar( grep {$_} @ArticleIDs ), 2, 'two articles created' );

my %ItemID;
my @Items = (
    [ DueSoon   => 'open',    DueDate   => $Minutes->(30) ],
    [ DueLater  => 'open',    DueDate   => $Minutes->( 3 * 24 * 60 ) ],
    [ Started   => 'waiting', DateStart => $Minutes->(-10) ],
    [ StartSoon => 'waiting', DateStart => $Minutes->(30) ],
);
my $Position = 1;
for my $Item (@Items) {
    my ( $Name, $Status, %Date ) = @{$Item};
    $ItemID{$Name} = $ChecklistObject->TicketChecklistAdd(
        TicketID => $TicketID,
        Title    => $Name,
        Status   => $Status,
        Position => $Position++,
        UserID   => 1,
        %Date,
    );
    $Self->True( $ItemID{$Name}, "checklist item $Name added" );
}

# ---------------------------------------------------------------------------
# the time windows the daemon jobs work on
# ---------------------------------------------------------------------------

$ConfigObject->Set( Key => 'TicketChecklist::DueDateBefore',          Value => 60 );
$ConfigObject->Set( Key => 'TicketChecklist::NotificationTimes',      Value => [] );
$ConfigObject->Set( Key => 'TicketChecklist::DateStartBefore',        Value => 60 );
$ConfigObject->Set( Key => 'TicketChecklist::StartNotificationTimes', Value => [] );

my %DueDateItems = map { $_ => 1 } $ChecklistObject->DueDateItems();
$Self->True( $DueDateItems{ $ItemID{DueSoon} }, 'DueDateItems: due in 30 minutes is found' );
$Self->False( $DueDateItems{ $ItemID{DueLater} }, 'DueDateItems: due in 3 days is not found' );

my %StartedItems = map { $_ => 1 } $ChecklistObject->StartedItems();
$Self->True( $StartedItems{ $ItemID{Started} }, 'StartedItems: start 10 minutes ago is found' );
$Self->False( $StartedItems{ $ItemID{StartSoon} }, 'StartedItems: start in 30 minutes is not found' );

my %DateStartItems = map { $_ => 1 } $ChecklistObject->DateStartItems();
$Self->True( $DateStartItems{ $ItemID{StartSoon} }, 'DateStartItems: start in 30 minutes is found' );
$Self->False( $DateStartItems{ $ItemID{Started} }, 'DateStartItems: start 10 minutes ago is not found' );

# ---------------------------------------------------------------------------
# the edit mask shows stored dates in the user's time zone
# ---------------------------------------------------------------------------

require Kernel::Modules::AgentTicketChecklist;
my %DateValues = Kernel::Modules::AgentTicketChecklist->_DateSelectionValues(
    TimeStamp => '2026-01-15 10:00:00',
    Prefix    => 'ItemDueDate_1_',
);
$Self->IsDeeply(
    \%DateValues,
    {
        ItemDueDate_1_Year   => 2026,
        ItemDueDate_1_Month  => 1,
        ItemDueDate_1_Day    => 15,
        ItemDueDate_1_Hour   => 11,
        ItemDueDate_1_Minute => 0,
    },
    'date selection: 10:00 UTC is shown as 11:00 Europe/Berlin',
);

# ---------------------------------------------------------------------------
# ticket PDF: checklist in front of the articles, article selection
# ---------------------------------------------------------------------------

my $PDFObject = $Kernel::OM->Get('Kernel::Output::PDF::TicketChecklist');

my ( @ChecklistCalls, @PrintedArticles );
my $OrigChecklist = \&Kernel::Output::PDF::TicketChecklist::_PDFOutputChecklist;
my $OrigArticles  = \&Kernel::Output::PDF::Ticket::_PDFOutputArticles;
{
    no warnings 'redefine';    ## no critic (TestingAndDebugging::ProhibitNoWarnings)
    local *Kernel::Output::PDF::TicketChecklist::_PDFOutputChecklist = sub {
        my ( $Object, %Param ) = @_;
        push @ChecklistCalls, $Param{TicketID};
        return $OrigChecklist->(@_);
    };
    local *Kernel::Output::PDF::Ticket::_PDFOutputArticles = sub {
        my ( $Object, %Param ) = @_;
        @PrintedArticles = map { $_->{ArticleID} } @{ $Param{ArticleData} };
        return $OrigArticles->(@_);
    };

    my $PDF = $PDFObject->GeneratePDF(
        TicketID  => $TicketID,
        UserID    => 1,
        Interface => 'Agent',
    );
    $Self->True( ( $PDF // '' ) =~ m{\A%PDF} ? 1 : 0, 'PDF without article selection is generated' );
    $Self->IsDeeply( \@ChecklistCalls, [$TicketID], 'checklist is printed for the ticket' );
    $Self->Is( scalar @PrintedArticles, 2, 'without a selection all articles are printed' );

    # one document per Kernel::System::PDF object, as in a web request
    $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::PDF'] );

    $PDF = $PDFObject->GeneratePDF(
        TicketID  => $TicketID,
        UserID    => 1,
        Interface => 'Agent',
        ArticleID => [ $ArticleIDs[1] ],
    );
    $Self->True( ( $PDF // '' ) =~ m{\A%PDF} ? 1 : 0, 'PDF with article selection is generated' );
    $Self->IsDeeply( \@PrintedArticles, [ $ArticleIDs[1] ], 'with a selection only the selected article is printed' );
}

# ---------------------------------------------------------------------------
# TicketDelete removes the checklist first (Kernel::Autoload::TicketChecklist)
# ---------------------------------------------------------------------------

$Self->True(
    defined $Kernel::Autoload::TicketChecklist::OrigTicketDelete ? 1 : 0,
    'autoload wrapper around TicketDelete is loaded',
);

$Self->True(
    $TicketObject->TicketDelete(
        TicketID => $TicketID,
        UserID   => 1,
    ),
    'ticket with checklist items can be deleted',
);

my @Remaining = $ChecklistObject->TicketChecklistTicketGet( TicketID => $TicketID );
$Self->Is( scalar @Remaining, 0, 'checklist items of the deleted ticket are gone' );

# cleanup is done by RestoreDatabase

$Self->DoneTesting();

1;
