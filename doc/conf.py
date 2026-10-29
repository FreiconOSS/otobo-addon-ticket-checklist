# Configuration file for the Sphinx documentation builder.

# -- Project information -----------------------------------------------------
project = 'OTOBO TicketChecklist'
copyright = '2026, Freicon; original work by Perl-Services.de'
author = 'Freicon'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx.ext.autosectionlabel',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'venv', '_shots', 'Thumbs.db', '.DS_Store']

# Make autosectionlabel references unique per document to avoid clashes.
autosectionlabel_prefix_document = True

# -- Options for HTML output -------------------------------------------------
html_theme = 'furo'
html_copy_source = False
html_show_sourcelink = False
html_static_path = ['_static']
html_css_files = ['custom.css']
html_theme_options = {
    'light_css_variables': {
        'color-brand-primary': '#1b6f8f',
        'color-brand-content': '#2d9fc7',
    },
    'dark_css_variables': {
        'color-brand-primary': '#45b4da',
        'color-brand-content': '#45b4da',
    },
}

# Source directory
source_suffix = '.rst'
master_doc = 'content/index'

# Language
language = 'de'

# Figure numbering
numfig = True
