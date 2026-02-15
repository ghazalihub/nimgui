const defaultStyleCSS* = """
.menu { fill: #CCCCCC; }
.menuitem { fill: #303030; }
.button { fill: #555555; }
.hovered { fill: #32809C; }
.pressed { fill: #32809C; }
.text { fill: #F2F2F2; }
"""

const defaultWidgetSVG* = """
<svg xmlns="http://www.w3.org/2000/svg">
  <g id="button" class="button" layout="box">
    <rect class="background" width="100" height="40" fill="#555555"/>
    <text class="title" x="10" y="25" fill="#F2F2F2">Button</text>
  </g>
  <g id="menu" class="menu" layout="flex" flex-direction="column">
    <rect class="background" width="150" height="200" fill="#CCCCCC"/>
  </g>
</svg>
"""
