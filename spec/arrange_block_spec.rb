# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter#arrange_block' do
  let :pdf_theme do
    {
      page_margin: 50,
      page_size: 'Letter',
      example_background_color: 'ffffcc',
      example_border_radius: 0,
      example_border_width: 0,
      sidebar_border_radius: 0,
      sidebar_border_width: 0,
    }
  end

  it 'should paint background over extent of empty block' do
    pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
    before block

    ====
    ====

    after block
    EOS

    pages = pdf.pages
    (expect pages).to have_size 1
    (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
    (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
    gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
    (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 702.22]
  end

  describe 'unbreakable block' do
    # NOTE: only add tests that verify at top ignores unbreakable option; otherwise, put test in breakable at top
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 674.44]
      end

      it 'should split block taller than page across pages starting from page top' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 437.17]
      end

      it 'should split block taller than several pages across pages starting from page top' do
        block_content = ['block content'] * 50 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 3
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end
    end

    describe 'below top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        before block

        [%unbreakable]
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 646.66]
      end

      it 'should advance block shorter than page to next page to avoid breaking' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 313.3]
      end

      it 'should advance block shorter than page and with caption to next page to avoid breaking' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_unique_text 'Example 1. block title')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'Example 1. block title')[:y]).to be > 723.009
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 294.309]
      end

      it 'should advance block shorter than page and with caption that wraps to next page to avoid breaking' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        block_title = ['block title'] * 20 * ' '
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, attributes: { 'example-caption' => nil }, analyze: true
        #{before_block_content}

        .#{block_title}
        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        block_title_texts = pdf.find_text %r/block title /
        (expect block_title_texts).to have_size 2
        (expect block_title_texts[0][:page_number]).to be 2
        (expect block_title_texts[0][:y]).to be > 723.009
        (expect block_title_texts[1][:y]).to be > 708.018
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 708.018], bottom_right: [562.0, 279.318]
      end

      it 'should split block taller than page across pages starting from current position' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        before block

        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 409.39]
      end

      it 'should advance block taller than page to next page if only caption fits on current page' do
        before_block_content = ['before block'] * 22 * %(\n\n)
        block_content = ['block content'] * 25 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ****
        filler
        ****

        #{before_block_content}

        .block title
        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[0][:page_number]).to be 1
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to have_size 1
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end

      it 'should advance block taller than page to next page if no content fits on current page' do
        before_block_content = ['before block'] * 22 * %(\n\n)
        block_content = ['block content'] * 25 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ====
        filler
        ====

        #{before_block_content}

        .block title
        [%unbreakable]
        ****
        #{block_content}
        ****
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[0][:page_number]).to be 1
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to have_size 1
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 687.19]
      end
    end
  end

  describe 'breakable block', breakable: true do
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 674.44]
      end

      it 'should split block taller than page across pages starting from page top' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 437.17]
      end

      it 'should split block taller than several pages starting from page top' do
        block_content = ['block content'] * 50 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 3
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end

      it 'should split block across pages that contains image that does not fit in remaining space on current page' do
        block_content = ['block content'] * 10 * %(\n\n)
        input = <<~EOS
        ====
        #{block_content}

        image::tux.png[pdfwidth=100%]
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 1
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 155.88235]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 742.0
      end

      it 'should split block across pages that contains image taller than page that follows text' do
        input = <<~EOS
        ====
        before image

        image::tall-diagram.png[]
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'before image')[:page_number]).to be 1
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 742.0
      end
    end

    describe 'below top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        before block

        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 646.66]
      end

      it 'should advance block shorter than page to next page if only caption fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        block_title = pdf.find_unique_text 'Example 1. block title'
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be > 723.009
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 294.309]
      end

      it 'should advance block shorter than page to next page if no content fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ****
        #{block_content}
        ****
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        block_title = pdf.find_unique_text 'block title'
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be < 742.0
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 284.82]
      end

      it 'should advance block taller than page to next page if only caption fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 30 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        block_title = pdf.find_unique_text 'Example 1. block title'
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be > 723.009
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 50.0]
      end

      it 'should advance block taller than page to next page if no content fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 30 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ****
        #{block_content}
        ****
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'block title')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 548.29]
      end

      it 'should split block shorter than page across pages starting from current position if it does not fit on current page' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 325.3], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 576.07]
      end

      it 'should split block taller than page across pages starting from current position' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 325.3], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end

      it 'should split block across pages that contains image that does not fit in remaining space on current page' do
        before_block_content = ['before block'] * 5 * %(\n\n)
        block_content = ['block content'] * 5 * %(\n\n)
        input = <<~EOS
        #{before_block_content}

        ====
        #{block_content}

        image::tux.png[pdfwidth=100%]
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 1
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 603.1], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 155.88235]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 742.0
      end

      it 'should advance block that starts with image that does not fit in remaining space on current page to next page' do
        before_block_content = ['before block'] * 10 * %(\n\n)
        input = <<~EOS
        #{before_block_content}

        ====
        image::tux.png[pdfwidth=100%]

        after image
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'after image')[:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 116.10235]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 730.0
      end

      it 'should advance block with caption that starts with image that does not fit in remaining space on current page to next page' do
        before_block_content = ['before block'] * 10 * %(\n\n)
        input = <<~EOS
        #{before_block_content}

        .block title
        ====
        image::tux.png[pdfwidth=100%]

        after image
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'Example 1. block title')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'after image')[:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 97.11135]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 711.009
      end
    end
  end

  describe 'multiple' do
    it 'should arrange block after another block has been arranged' do
      before_block_content = ['before block'] * 35 * %(\n\n)
      block_content = ['block content'] * 15 * %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
      [%unbreakable]
      ====
      #{before_block_content}
      ====

      between

      [%unbreakable]
      ====
      #{block_content}
      ====
      EOS

      pages = pdf.pages
      (expect pages).to have_size 3
      (expect (pdf.find_text 'before block')[0][:page_number]).to be 1
      (expect (pdf.find_text 'before block')[-1][:page_number]).to be 2
      (expect (pdf.find_text 'block content')[0][:page_number]).to be 3
      (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
      p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
      (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
      p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
      (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 437.17]
      p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
      (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 313.3]
    end
  end

  describe 'anchor' do
    it 'should keep anchor with unbreakable block when advanced to new page' do
      before_block_content = ['before block'] * 15 * %(\n\n)
      block_content = ['block content'] * 15 * %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: pdf_theme
      #{before_block_content}

      [#block-id%unbreakable]
      ====
      #{block_content}
      ====
      EOS

      pages = pdf.pages
      (expect (pages[0].text.split %r/\n+/).uniq.compact).to eql ['before block']
      (expect (pages[1].text.split %r/\n+/).uniq.compact).to eql ['block content']
      (expect pages).to have_size 2
      dest = get_dest pdf, 'block-id'
      (expect dest[:page_number]).to be 2
      (expect dest[:y].to_f).to eql 742.0
    end

    it 'should keep anchor with breakable block when advanced to next page' do
      before_block_content = ['before block'] * 24 * %(\n\n)
      block_content = ['block content'] * 15 * %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: pdf_theme
      #{before_block_content}

      .block title
      [#block-id]
      ====
      #{block_content}
      ====
      EOS

      pages = pdf.pages
      (expect pages).to have_size 2
      dest = get_dest pdf, 'block-id'
      (expect dest[:page_number]).to be 2
      (expect dest[:y].to_f).to eql 742.0
    end
  end
end
