# --
# Kernel/Output/PDF/TicketChecklist.pm - ticket PDF with the checklist of the ticket
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::PDF::TicketChecklist;

use strict;
use warnings;

use parent qw(Kernel::Output::PDF::Ticket);

use Kernel::System::VariableCheck qw(IsArrayRefWithData);

our @ObjectDependencies = (
    @Kernel::Output::PDF::Ticket::ObjectDependencies,
    'Kernel::System::PerlServices::TicketChecklist',
);

=head1 NAME

Kernel::Output::PDF::TicketChecklist - ticket PDF with the checklist of the ticket

=head1 DESCRIPTION

Extends the core ticket PDF (L<Kernel::Output::PDF::Ticket>) instead of replacing it:
the checklist table is printed in front of the articles, and C<ArticleID> may be a
list of article IDs, so that only the articles selected in the ticket zoom are printed.

=head1 PUBLIC INTERFACE

=head2 GeneratePDF()

Same parameters as the core method, plus:

    my $PDFString = $Kernel::OM->Get('Kernel::Output::PDF::TicketChecklist')->GeneratePDF(
        TicketID  => 123,
        UserID    => 1,
        Interface => 'Agent',
        ArticleID => [ 12, 15 ],    # optional, prints only these articles
    );

=cut

sub GeneratePDF {
    my ( $Self, %Param ) = @_;

    $Self->{ChecklistTicketID} = $Param{TicketID};

    # the core method takes a single article ID only, the selection is applied in _PDFOutputArticles
    $Self->{ChecklistArticleIDs} = undef;
    if ( IsArrayRefWithData( $Param{ArticleID} ) ) {
        $Self->{ChecklistArticleIDs} = { map { $_ => 1 } @{ delete $Param{ArticleID} } };
    }

    return $Self->SUPER::GeneratePDF(%Param);
}

sub _PDFOutputArticles {
    my ( $Self, %Param ) = @_;

    $Self->_PDFOutputChecklist(
        PageData => $Param{PageData},
        TicketID => $Self->{ChecklistTicketID},
    );

    if ( $Self->{ChecklistArticleIDs} && IsArrayRefWithData( $Param{ArticleData} ) ) {
        $Param{ArticleData} = [
            grep { $Self->{ChecklistArticleIDs}->{ $_->{ArticleID} } } @{ $Param{ArticleData} }
        ];
    }

    return $Self->SUPER::_PDFOutputArticles(%Param);
}

sub _PDFOutputChecklist {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    # check needed stuff
    for my $Needed (qw(PageData TicketID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my %Page = %{ $Param{PageData} };

    my %TableParam;
    my $Row = 0;

    my @ChecklistItems = $ChecklistObject->TicketChecklistTicketGet(
        TicketID => $Param{TicketID},
    );

    return if !@ChecklistItems;

    my $PrintComment = $ConfigObject->Get('TicketChecklist::PrintItemComment');

    for my $Item ( @ChecklistItems ) {
        $TableParam{CellData}[$Row][0]{Content} = $Item->{Position} || '';
        $TableParam{CellData}[$Row][1]{Content} = $LayoutObject->{LanguageObject}->Translate( $Item->{Priority} || '' );
        $TableParam{CellData}[$Row][2]{Content} = $Item->{Title} || '';
        $TableParam{CellData}[$Row][3]{Content} = $LayoutObject->{LanguageObject}->Translate( $Item->{Status} || '' );
        $TableParam{CellData}[$Row][4]{Content} = $Item->{Responsible} || '';

        # items without a due date are allowed
        my $Time = '';
        if ( $Item->{DueDate} ) {
            $Time = $LayoutObject->{LanguageObject}->FormatTimeString(
                $Item->{DueDate},
                'DateFormat',
            );
        }

        $TableParam{CellData}[$Row][5]{Content} = $Time;
        $Row++;

        if ( $PrintComment && defined $Item->{Comment} && $Item->{Comment} ne '' ) {
            $TableParam{CellData}[$Row][0]{Content} = '';
            $TableParam{CellData}[$Row][1]{Content} = '';
            $TableParam{CellData}[$Row][2]{Content} = $Item->{Comment} // '';
            $Row++;
        }
    }

    $TableParam{ColumnData}[0]{Width} = 8;
    $TableParam{ColumnData}[1]{Width} = 30;
    $TableParam{ColumnData}[2]{Width} = 200;
    $TableParam{ColumnData}[3]{Width} = 45;
    $TableParam{ColumnData}[4]{Width} = 80;
    $TableParam{ColumnData}[5]{Width} = 60;

    # get PDF object
    my $PDFObject = $Kernel::OM->Get('Kernel::System::PDF');

    $PDFObject->HLine(
        Color     => '#aaa',
        LineWidth => 0.5,
    );

    # set new position
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -10,
    );

    # output headline
    $PDFObject->Text(
        Text     => $LayoutObject->{LanguageObject}->Translate('Checklist'),
        Height   => 10,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 9,
        Color    => '#666666',
    );

    # set new position
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -4,
    );

    # table params
    $TableParam{Type}          = 'Cut';
    $TableParam{Border}        = 0;
    $TableParam{FontSize}      = 6;
    $TableParam{Padding}       = 1;
    $TableParam{PaddingTop}    = 3;
    $TableParam{PaddingBottom} = 3;

    # output table
    PAGE:
    for ( $Page{PageCount} .. $Page{MaxPages} ) {

        # output table (or a fragment of it)
        %TableParam = $PDFObject->Table( %TableParam, );

        # stop output or output next page
        if ( $TableParam{State} ) {
            last PAGE;
        }
        else {
            $PDFObject->PageNew(
                %Page,
                FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
            );
            $Page{PageCount}++;
        }
    }

    return 1;
}
# ---

1;
