# -*- coding: utf-8 -*-
{
    "name": "Product Connect Module",
    "version": "17.0.3.1",
    "category": "Industries",
    "author": "Chris Busillo",
    "company": "Shiny Computers",
    "website": "https://www.shinycomputers.com",
    "depends": [
        "base",
        "product",
        "web",
        "website_sale",
        "base_automation",
        "stock",
        "mail",
        "project",
    ],
    "description": "Module to scrape websites for model data.",
    "data": [
        "data/motor_test_section_data.xml",  # motor data order is important (relations)
        "data/motor_test_selection_data.xml",
        "data/motor_test_template_data.xml",
        "data/motor_part_template_data.xml",
        "data/motor_stat_data.xml",
        "data/motor_product_template_data.xml",
        "data/res_config_data.xml",
        "report/motor_reports.xml",
        "report/product_reports.xml",
        "views/motor_views.xml",  # motor_views needs to be loaded first (menu parent)
        "views/motor_part_template_views.xml",
        "views/motor_product_template_views.xml",
        "views/motor_test_template_views.xml",
        "views/motor_test_selection_views.xml",
        "views/motor_test_section_views.xml",
        "views/printnode_interface_views.xml",
        "views/product_color_views.xml",
        "views/product_import_views.xml",
        "views/product_import_wizard.xml",
        "views/product_product_views.xml",
        "views/product_template_views.xml",
        "views/product_manufacturer_views.xml",
        "views/project_task_views.xml",
        "views/res_users_views.xml",
        "security/ir.model.access.csv",
    ],
    "assets": {
        "web.assets_backend": [
            "product_connect/static/src/scss/*",
            "product_connect/static/src/js/*",
            "product_connect/static/src/xml/*",
        ],
    },
    "installable": True,
    "application": True,
    "license": "LGPL-3",
}
